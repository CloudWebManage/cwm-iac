import os
import time
import subprocess


def get_metrics():
    metrics = {}
    for line in subprocess.check_output(["curl", "-s", "http://localhost:49999/metrics"]).decode().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            metric, value = line.split(" ")
            if "{" in metric:
                name, labels, *_ = metric.split("{")
                labels = labels.rstrip("}")
                labels_ = {}
                for label in labels.split(","):
                    key, val = label.split("=")
                    labels_[key] = val.strip('"')
                labels = labels_
            else:
                name = metric
                labels = {}
            metrics.setdefault(name, []).append({"value": int(value), **labels})
    return metrics


def get_metric_value(metrics, metric_name, labels):
    for metric in metrics.get(metric_name, []):
        if all(item in metric.items() for item in labels.items()):
            return metric["value"]
    return None


def test():
    try:
        subprocess.check_call([
            "docker", "compose", "-f", "test_docker_compose.yaml",
            "up", "--wait", "--yes", "--force-recreate", "--remove-orphans", "--build"
        ], cwd=os.path.join(os.path.dirname(__file__)))
        time.sleep(5)
        assert get_metrics() == {
            "nginx_metric_errors_total": [{"value": 0}]
        }
        metrics = get_metrics()
        assert get_metric_value(metrics, "nginx_http_request_duration_seconds_bucket", {"host": "_", "le": "0.005"}) == 1
        assert get_metric_value(metrics, "nginx_http_request_size_bytes_count", {"host": "_"}) == 1
        assert get_metric_value(metrics, "nginx_http_response_size_bytes_sum", {"host": "_"}) > 200
    finally:
        subprocess.call([
            "docker", "compose", "-f", "test_docker_compose.yaml", "down", "-v"
        ], cwd=os.path.join(os.path.dirname(__file__)))
