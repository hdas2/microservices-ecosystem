#!/bin/bash

# Set default namespace
NAMESPACE="shared-dbs"

# Deploy shared databases using Helm
helm upgrade --install shared-dbs ./helm/charts/shared-dbs \
  --namespace $NAMESPACE \
  --create-namespace \
  --set mysql.auth.password="mysql_password_123" \
  --set mongodb.auth.password="mongo_password_123" \
  --set redis.auth.password="redis_password_123"

# Wait for databases to be ready
echo "Waiting for databases to become ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mysql --timeout=300s -n $NAMESPACE
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mongodb --timeout=300s -n $NAMESPACE
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis --timeout=300s -n $NAMESPACE

# Initialize databases
./scripts/init-dbs.sh

# Print connection information
echo -e "\n\e[1mDatabase Connection Strings:\e[0m"
echo "MySQL: mysql://shared_user:mysql_password_123@mysql.shared-dbs.svc.cluster.local:3306/shared_db"
echo "MongoDB: mongodb://shared_user:mongo_password_123@mongodb.shared-dbs.svc.cluster.local:27017/shared_db?authSource=admin"
echo "Redis: redis://:redis_password_123@redis.shared-dbs.svc.cluster.local:6379"