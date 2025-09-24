import os
import time
import shutil
import difflib
import tempfile
import subprocess

from . import entrypoint


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


def test_e2e():
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


def assert_files_equal(file1, file2):
    with open(file1) as f1, open(file2) as f2:
        content1 = f1.readlines()
        content2 = f2.readlines()
        assert content1 == content2


def assert_file_contains(file, substring):
    with open(file) as f:
        content = f.read()
        assert substring in content


def test_entrypoint():
    with tempfile.TemporaryDirectory() as tmpdir:
        etc_nginx_path = os.path.join(tmpdir, "etc_nginx")
        url_local_openresty_nginx_path = os.path.join(tmpdir, "url_local_openresty_nginx")
        os.makedirs(etc_nginx_path)
        os.makedirs(f'{url_local_openresty_nginx_path}/conf')
        localpath = os.path.dirname(__file__)
        shutil.copy(f'{localpath}/nginx.conf', f'{url_local_openresty_nginx_path}/conf/nginx.conf')
        shutil.copy(f'{localpath}/metrics.conf', f'{etc_nginx_path}/metrics.conf')
        shutil.copy(f'{localpath}/metrics_server.conf', f'{etc_nginx_path}/metrics_server.conf')
        entrypoint.main(etc_nginx_path, url_local_openresty_nginx_path)
        assert_files_equal(f'{localpath}/nginx.conf', f'{url_local_openresty_nginx_path}/conf/nginx.conf')
        assert_files_equal(f'{localpath}/metrics.conf', f'{etc_nginx_path}/metrics.conf')
        assert_files_equal(f'{localpath}/metrics_server.conf', f'{etc_nginx_path}/metrics_server.conf')
        os.environ.update({
            'WORKER_CONNECTIONS': '2048',
            'WORKER_PROCESSES': '4',
            'ERROR_LOG_LEVEL': 'warn',
            'METRICS_LUA_SHARED_DICT_SIZE': '32m',
            'METRICS_SERVER_PORT': '8888',
        })
        entrypoint.main(etc_nginx_path, url_local_openresty_nginx_path)
        assert_file_contains(f'{url_local_openresty_nginx_path}/conf/nginx.conf', 'worker_connections  2048;')
        assert_file_contains(f'{url_local_openresty_nginx_path}/conf/nginx.conf', 'worker_processes 4;')
        assert_file_contains(f'{url_local_openresty_nginx_path}/conf/nginx.conf', 'error_log  stderr  warn;')
        assert_file_contains(f'{etc_nginx_path}/metrics.conf', 'lua_shared_dict prometheus_metrics 32m;')
        assert_file_contains(f'{etc_nginx_path}/metrics_server.conf', 'listen 8888;')
