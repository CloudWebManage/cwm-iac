"""Characterize actual metric names/labels, using disposable local containers only."""
import json
import os
import time

from prometheus_client.parser import text_string_to_metric_families
import requests
import yaml

from tests.containers import container, docker
from tests.test_objstore_monitoring import ROOT, evaluate, render, resource, tenant_values
from tests.minio_log_metrics.test_vector_contract import IMAGE, CONFIG, audit


def endpoint(identifier, port):
    address = docker("port", identifier, str(port), text=True).stdout.splitlines()[0]
    # Local Docker is the portable default; remote daemons need an explicit host.
    host = os.environ.get("TEST_DOCKER_HOST", "127.0.0.1")
    return f"http://{host}:{address.rsplit(':', 1)[1]}"


def wait_for(check, timeout=45):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            result = check()
            if result:
                return result
        except (requests.ConnectionError, requests.Timeout):
            pass
        time.sleep(0.25)
    raise AssertionError("Timed out waiting for disposable exporter")


def samples(url):
    response = requests.get(url + "/metrics", timeout=3)
    response.raise_for_status()
    return [sample for family in text_string_to_metric_families(response.text) for sample in family.samples]


def test_pinned_vector_exports_real_buffer_and_delivery_error_metrics():
    config = yaml.safe_load(CONFIG.read_text())
    with container(IMAGE, ["--config", "/etc/vector/vector.yaml"], {"etc/vector/vector.yaml": yaml.safe_dump(config)}, ["-p", "9598", "-p", "8791"]) as identifier:
        docker("start", identifier)
        metrics_url = endpoint(identifier, 9598)
        audit_url = endpoint(identifier, 8791)
        wait_for(lambda: requests.post(audit_url, json=audit(200), timeout=3).status_code == 200)
        assert requests.post(audit_url, data="invalid-json", timeout=3).status_code == 400
        observed = wait_for(lambda: [s for s in samples(metrics_url) if s.name == "vector_http_client_errors_total" and s.labels.get("component_id") == "access_updater"])
        assert observed[0].value > 0
        source_errors = [s for s in samples(metrics_url) if s.name == "vector_component_errors_total" and s.labels.get("component_id") == "minio_audit"]
        assert source_errors and source_errors[0].value > 0
        buffer = [s for s in samples(metrics_url) if s.name == "vector_buffer_byte_size" and s.labels.get("component_id") == "access_updater"]
        assert len(buffer) == 1
        assert buffer[0].value > 0
        capacity = [s for s in samples(metrics_url) if s.name == "vector_buffer_max_byte_size" and s.labels.get("component_id") == "access_updater"]
        assert capacity[0].value == 5368709120
        assert not any(s.name.startswith("minio_audit_") for s in samples(metrics_url))


def test_redis_configuration_and_pinned_exporter_metrics(tmp_path):
    profile = json.loads((ROOT / "docs/examples/objstore-load-test.tfvars.json").read_text())
    config = evaluate(tmp_path, profile)
    deployment = resource(render(tmp_path, "minio-tenant", tenant_values(config)), "Deployment", "tierer-redis")
    redis, exporter = deployment["spec"]["template"]["spec"]["containers"]
    with container(redis["image"], redis["command"], options=["-p", "9121"]) as redis_id:
        docker("start", redis_id)
        with container(exporter["image"], exporter["args"], options=["--network", f"container:{redis_id}"]) as exporter_id:
            docker("start", exporter_id)
            url = endpoint(redis_id, 9121)
            observed = wait_for(lambda: [s for s in samples(url) if s.name == "redis_up" and s.value == 1])
            assert observed
            names = {s.name for s in samples(url)}
            assert names >= {"redis_memory_used_bytes", "redis_memory_max_bytes", "redis_evicted_keys_total"}
            settings = json.loads(docker("exec", redis_id, "redis-cli", "--json", "CONFIG", "GET", "appendonly", "appendfsync", "maxmemory", "maxmemory-policy", text=True).stdout)
            assert settings == {"appendonly": "yes", "appendfsync": "everysec", "maxmemory": "1073741824", "maxmemory-policy": "noeviction"}
