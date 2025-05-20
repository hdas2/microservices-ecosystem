def call(Map config) {
    pipeline {
        agent any
        environment {
            KUBECONFIG = credentials('eks-kubeconfig')
            HELM_EXTRA_ARGS = "--atomic --timeout 5m0s"
            PYTHON_HOME = "/usr/bin/python3.13"
            PATH = "/usr/bin:$PATH"
        }
        stages {
            stage('Build') {
                steps {
                    script {
                        docker.build("${config.registry}/${config.serviceName}:${env.BUILD_NUMBER}")
                    }
                }
            }
            stage('Test') {
                steps {
                    sh config.testCommand
                }
            }
            stage('Push') {
                steps {
                    script {
                        docker.withRegistry("https://${config.registry}", 'ecr-credentials') {
                            docker.image("${config.registry}/${config.serviceName}:${env.BUILD_NUMBER}").push()
                        }
                    }
                }
            }
            stage('Deploy Canary') {
                steps {
                    sh """
                        helm upgrade ${config.serviceName}-canary ${config.helmRepo}/${config.serviceName} \
                            ${HELM_EXTRA_ARGS} \
                            --install \
                            --namespace ${config.namespace} \
                            --set image.tag=${env.BUILD_NUMBER} \
                            --set replicaCount=1 \
                            --set canary.enabled=true \
                            --set canary.trafficPercent=${config.canaryTrafficPercent} \
                            --set istio.virtualService.canary=true
                    """
                }
            }
            stage('Verify Canary') {
                steps {
                    script {
                        // Run smoke tests
                        sh config.smokeTestCommand
                        
                        // Verify metrics
                        def prometheusUrl = "http://prometheus-operated.monitoring:9090"
                        def errorRate = getPrometheusMetric("""
                            rate(http_request_errors_total{service='${config.serviceName}-canary'}[1m])
                        """)
                        
                        if (errorRate > config.errorThreshold) {
                            error("Canary error rate ${errorRate} exceeds threshold ${config.errorThreshold}")
                        }
                        
                        // Check logs for critical errors
                        def logErrors = sh(
                            script: """
                                kubectl logs -l app=${config.serviceName}-canary -n ${config.namespace} \
                                | grep -i '${config.errorPattern}' | wc -l
                            """,
                            returnStdout: true
                        ).trim().toInteger()
                        
                        if (logErrors > 0) {
                            error("Found ${logErrors} critical errors in canary logs")
                        }
                    }
                }
            }
            stage('Promote to Production') {
                when {
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                }
                steps {
                    sh """
                        helm upgrade ${config.serviceName} ${config.helmRepo}/${config.serviceName} \
                            ${HELM_EXTRA_ARGS} \
                            --install \
                            --namespace ${config.namespace} \
                            --set image.tag=${env.BUILD_NUMBER} \
                            --set replicaCount=${config.prodReplicaCount} \
                            --set canary.enabled=false
                    """
                    sh "helm uninstall ${config.serviceName}-canary --namespace ${config.namespace}"
                }
            }
        }
        post {
            always {
                script {
                    // Archive test results
                    junit '**/test-results/*.xml'
                    
                    // Send notification
                    emailext body: "Pipeline ${currentBuild.fullDisplayName} completed with status: ${currentBuild.result}",
                             subject: "Pipeline ${currentBuild.result}: ${env.JOB_NAME}",
                             to: 'devops-team@example.com'
                }
            }
            failure {
                sh "helm uninstall ${config.serviceName}-canary --namespace ${config.namespace} || true"
                script {
                    // Capture failure diagnostics
                    sh "kubectl describe pod -l app=${config.serviceName}-canary -n ${config.namespace} > diagnostics.txt"
                    archiveArtifacts 'diagnostics.txt'
                }
            }
        }
    }
}

def getPrometheusMetric(String query) {
    def response = sh(
        script: """
            curl -sG --data-urlencode 'query=${query}' \
            'http://prometheus-operated.monitoring:9090/api/v1/query' \
            | jq -r '.data.result[0].value[1]'
        """,
        returnStdout: true
    ).trim()
    return response ? response.toFloat() : 0.0
}