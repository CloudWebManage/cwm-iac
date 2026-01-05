import os
import time
import subprocess

from prometheus_client.parser import text_string_to_metric_families


def dc(*args):
    basepath = os.path.dirname(__file__)
    subprocess.check_call([
        "docker", "compose", *args
    ], cwd=basepath)


def mc(*args):
    basepath = os.path.dirname(__file__)
    subprocess.check_call([
        "docker", "compose", "exec", "minio", "mc", *args
    ], cwd=basepath)


def test():
    try:
        dc("down", "-v")
    except subprocess.CalledProcessError:
        pass
    dc("up", "-d", "--build", "--force-recreate", "--remove-orphans", "--wait")
    time.sleep(1)
    try:
        mc("alias", "set", "local", "http://localhost:9000", "admin", "12345678")
        mc("mb", "local/test")
        mc("cp", "/bin/mc", "local/test/")
        mc("ls", "local/test/")
        mc("cp", "local/test/mc", "/tmp/mc_copy")
        mc("cp", "local/test/mc", "/tmp/mc_copy2")
        time.sleep(2)
        out = subprocess.check_output([
            "docker", "compose", "exec", "minio", "curl", "-s", "minio-log-metrics:8799/metrics"
        ], cwd=os.path.dirname(__file__)).decode()
        metric_values = {}
        metric_labels = {}
        for metric in text_string_to_metric_families(out):
            for sample in metric.samples:
                if sample.labels.get("bucket") == "test":
                    metric_name = sample.name
                    if metric_name == "minio_audit_operations_total":
                        metric_name = f'minio_audit_operations_total_{sample.labels["direction"]}'
                    assert metric_name not in metric_values and metric_name not in metric_labels, f'duplicate metric samples found: {out}'
                    metric_values[metric_name] = sample.value
                    metric_labels[metric_name] = sample.labels
        assert metric_labels == {
            "minio_audit_bytes_received_total": {
                "bucket": "test",
                "access_key": "admin",
            },
            "minio_audit_bytes_sent_total": {
                "bucket": "test",
                "access_key": "admin",
            },
            "minio_audit_operations_total_in": {
                "bucket": "test",
                "access_key": "admin",
                "direction": "in",
            },
            "minio_audit_operations_total_out": {
                "bucket": "test",
                "access_key": "admin",
                "direction": "out",
            }
        }
        assert metric_values["minio_audit_bytes_received_total"] > 30000000
        assert metric_values["minio_audit_bytes_sent_total"] > 60000000
        assert metric_values["minio_audit_operations_total_in"] > 13
        assert metric_values["minio_audit_operations_total_out"] > 1
    finally:
        dc("down", "-v")
