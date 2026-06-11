prometheus = require("prometheus").init("prometheus_metrics")
metric_requests = prometheus:counter("nginx_http_requests_total", "Number of HTTP requests", {"host", "status"})
metric_latency = prometheus:histogram("nginx_http_request_duration_seconds", "HTTP request latency", {"host"})
metric_response_size = prometheus:histogram(
    "nginx_http_response_size_bytes", "HTTP response size", {"host"},
    { 128, 512, 1024, 4096, 16384, 65536, 262144, 1048576, 4194304, 16777216 }
)
metric_request_size = prometheus:histogram(
    "nginx_http_request_size_bytes", "HTTP request size", {"host"},
    { 128, 512, 1024, 4096, 16384, 65536, 262144, 1048576, 4194304, 16777216 }
)
