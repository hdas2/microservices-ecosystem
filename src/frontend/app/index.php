<?php
require_once __DIR__.'/vendor/autoload.php';

use OpenTelemetry\API\Trace\TracerProvider;
use OpenTelemetry\SDK\Trace\TracerProviderFactory;
use OpenTelemetry\Contrib\Otlp\OtlpHttpTransportFactory;
use OpenTelemetry\Contrib\Otlp\SpanExporter;
use OpenTelemetry\SDK\Resource\ResourceInfo;
use OpenTelemetry\SemConv\ResourceAttributes;

// Initialize OpenTelemetry
$transport = (new OtlpHttpTransportFactory())->create(
    getenv('OTEL_EXPORTER_OTLP_ENDPOINT'),
    'application/x-protobuf'
);
$exporter = new SpanExporter($transport);

$resource = ResourceInfo::create(ResourceAttributes::create([
    'service.name' => getenv('OTEL_SERVICE_NAME') ?: 'frontend-service',
]));

$tracerProvider = (new TracerProviderFactory())->create($exporter, $resource);
TracerProvider::setInstance($tracerProvider);

$tracer = TracerProvider::getTracer('frontend');

// Example route handling
if ($_SERVER['REQUEST_URI'] === '/cart') {
    $span = $tracer->spanBuilder('display_cart')->startSpan();
    
    try {
        // Fetch cart data from cart service
        $cartData = file_get_contents(getenv('CART_SERVICE_URL').'/cart/123');
        echo "Cart Page: " . $cartData;
    } finally {
        $span->end();
    }
} elseif ($_SERVER['REQUEST_URI'] === '/products') {
    $span = $tracer->spanBuilder('display_products')->startSpan();
    
    try {
        // Fetch product data from product service
        $productData = file_get_contents(getenv('PRODUCT_SERVICE_URL').'/product/1/summary');
        echo "Product Page: " . $productData;
    } finally {
        $span->end();
    }
} else {
    echo "Welcome to our e-commerce site!";
}