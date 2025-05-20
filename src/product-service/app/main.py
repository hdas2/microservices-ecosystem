from fastapi import FastAPI, Depends
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from prometheus_fastapi_instrumentator import Instrumentator
import mysql.connector
import redis
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.instrumentation.mysql import MySQLInstrumentor
import os

# Setup OpenTelemetry
resource = Resource(attributes={
    "service.name": os.getenv("OTEL_SERVICE_NAME", "product-service")
})
trace.set_tracer_provider(TracerProvider(resource=resource))
otlp_exporter = OTLPSpanExporter(endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT"))
trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(otlp_exporter))

# Instrumentations
RedisInstrumentor().instrument()
MySQLInstrumentor().instrument()

app = FastAPI()

# Database connections
def get_db():
    return mysql.connector.connect(
        host="mysql-service",
        user=os.getenv("DB_USER", "user"),
        password=os.getenv("DB_PASSWORD", "password"),
        database=os.getenv("DB_NAME", "product_db")
    )

def get_redis():
    return redis.Redis.from_url(os.getenv("REDIS_URL"))

# Prometheus metrics
Instrumentator().instrument(app).expose(app)

@app.get("/product/{product_id}/summary")
async def get_product_summary(product_id: int):
    tracer = trace.get_tracer(__name__)
    with tracer.start_as_current_span("get_product_summary"):
        # Implementation here
        return {"product_id": product_id, "summary": "Detailed product summary"}

FastAPIInstrumentor.instrument_app(app)