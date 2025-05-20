const express = require('express');
const mongoose = require('mongoose');
const redis = require('redis');
const { MeterProvider } = require('@opentelemetry/metrics');
const { PrometheusExporter } = require('@opentelemetry/exporter-prometheus');
const { NodeTracerProvider } = require('@opentelemetry/node');
const { SimpleSpanProcessor } = require('@opentelemetry/tracing');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { RedisInstrumentation } = require('@opentelemetry/instrumentation-redis');
const { MongooseInstrumentation } = require('@opentelemetry/instrumentation-mongoose');
const { registerInstrumentations } = require('@opentelemetry/instrumentation');
const promBundle = require('express-prom-bundle');
require('dotenv').config();

// Initialize OpenTelemetry
const tracerProvider = new NodeTracerProvider();
tracerProvider.addSpanProcessor(
  new SimpleSpanProcessor(
    new OTLPTraceExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT
    })
  )
);
tracerProvider.register();

// Instrumentations
registerInstrumentations({
  instrumentations: [
    new RedisInstrumentation(),
    new MongooseInstrumentation()
  ]
});

// Prometheus metrics
const metricsMiddleware = promBundle({
  includeMethod: true,
  includePath: true,
  normalizePath: [['^/cart/.*', '/cart/#id']],
  promClient: {
    collectDefaultMetrics: {}
  }
});

const app = express();
app.use(metricsMiddleware);

// MongoDB connection
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true
});

// Redis connection
const redisClient = redis.createClient({
  url: process.env.REDIS_URL
});
redisClient.on('error', (err) => console.log('Redis Client Error', err));
redisClient.connect();

// Routes
app.get('/cart/:userId', async (req, res) => {
  // Implementation here
  res.json({ userId: req.params.userId, items: [] });
});

app.get('/catalogue', async (req, res) => {
  // Implementation here
  res.json({ products: [] });
});

app.listen(3000, () => {
  console.log('Cart service running on port 3000');
});