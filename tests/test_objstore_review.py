"""Regressions for scanner image precedence, Grafana provisioning and test portability."""
import json
import secrets
import subprocess

import pytest
import yaml

from tests.containers import container
from tests.test_objstore_monitoring import ROOT, env, evaluate, render, resource, tenant_values
from tests import test_objstore_exporters as exporters

LEGACY_VALUES = ROOT / "tests/fixtures/objstore/legacy-tierer-values.yaml"
COMPATIBLE_SCANNER = "ghcr.io/cloudwebmanage/cwm-minio-tierer:34ef901cf197b7479e25714184a68d84ca0d0943"
LEGACY_UPDATER = "ghcr.io/cloudwebmanage/cwm-minio-tierer:aa0cbe581d39be5f88c12c57f3d6d9075beea454"


def scanner_from(docs):
    return resource(docs, "Deployment", "tierer-server")["spec"]["template"]["spec"]["containers"][0]


def assert_scanner_accepts_configuration(scanner, monkeypatch):
    # Run the selected registry binary, not a reimplementation of its config parser.
    # No external networking or services: successful config parsing proceeds to
    # the expected Redis readiness failure (exit 1); invalid config exits 2.
    settings = env(scanner)
    settings["REDIS_ADDR"] = "127.0.0.1:6379"
    options = ["--network", "none"]
    for key, value in settings.items():
        options.extend(["-e", f"{key}={value}"])
    for key in ("MINIO_ACCESS_KEY", "MINIO_SECRET_KEY"):
        # Ephemeral placeholders never enter argv, fixture files, reports or logs.
        monkeypatch.setenv(key, secrets.token_hex(16))
        options.extend(["-e", key])
    with container(scanner["image"], options=options) as identifier:
        result = subprocess.run(["docker", "start", "-a", identifier], capture_output=True, text=True, timeout=15)
        assert result.returncode == 1, result.stdout + result.stderr
        records = [json.loads(line) for line in result.stdout.splitlines()]
        assert any("Redis readiness" in record.get("error", "") for record in records), records
        assert not any("invalid MinIO tierer configuration" in record.get("msg", "") for record in records)


def test_legacy_scanner_value_file_survives_implicit_module_defaults(tmp_path, monkeypatch):
    config = evaluate(tmp_path)
    docs = render(tmp_path, "minio-tenant", tenant_values(config), value_files=[LEGACY_VALUES])
    scanner = scanner_from(docs)
    assert scanner["image"] == COMPATIBLE_SCANNER
    # Even a compatible fallback must not overwrite a future config-file selection.
    assert "cwmMinioTierer" not in config["tierer"]
    assert_scanner_accepts_configuration(scanner, monkeypatch)


def test_fallback_scanner_binary_accepts_legacy_policy_defaults(tmp_path, monkeypatch):
    config = evaluate(tmp_path)
    scanner = scanner_from(render(tmp_path, "minio-tenant", tenant_values(config)))
    settings = env(scanner)
    assert settings["TIERER_MODE"] == "apply"
    assert settings["TIERER_COVERAGE_ENABLED"] == "false"
    assert not any(key.startswith("TIERER_DAILY_") for key in settings)
    assert_scanner_accepts_configuration(scanner, monkeypatch)
    assert scanner["image"] == COMPATIBLE_SCANNER


@pytest.mark.parametrize("image", [None, "", LEGACY_UPDATER, COMPATIBLE_SCANNER])
def test_monitoring_requires_explicit_new_shared_image(tmp_path, image):
    profile = json.loads((ROOT / "docs/examples/objstore-load-test.tfvars.json").read_text())
    profile["minio_tierer_image"] = image
    with pytest.raises(subprocess.CalledProcessError):
        evaluate(tmp_path, profile)


def test_explicit_monitoring_image_reaches_both_binaries_over_legacy_values(tmp_path):
    profile = json.loads((ROOT / "docs/examples/objstore-load-test.tfvars.json").read_text())
    profile["minio_tierer_image"] = "ghcr.io/cloudwebmanage/cwm-minio-tierer:explicit-new-build"
    config = evaluate(tmp_path, profile)
    docs = render(tmp_path, "minio-tenant", tenant_values(config), value_files=[LEGACY_VALUES])
    scanner = scanner_from(docs)
    updater = next(c for c in resource(docs, "Tenant", "test")["spec"]["sideCars"]["containers"] if c["name"] == "cwm-minio-tierer-access-updater")
    assert scanner["image"] == updater["image"] == profile["minio_tierer_image"]
    assert env(updater)["UPDATER_METRICS_LISTEN_ADDR"] == "0.0.0.0:8922"
    assert env(updater)["UPDATER_LISTEN_ADDR"] == "127.0.0.1:8921"


def test_two_tenants_have_distinct_grafana_files_and_folder_title_identities(tmp_path):
    files, titles, uids = set(), set(), set()
    for tenant in ("minio-tenant-review-one", "minio-tenant-review-two"):
        url = f"http://{tenant}-prometheus:80"
        docs = render(tmp_path, "grafana-dashboards", {"minio": {
            "enabled": True, "objstoreMonitoring": True,
            "prometheusUrl": url, "namespaces": {"tenant": tenant},
        }})
        provisioned = {key: value for doc in docs if doc["metadata"]["name"].startswith("grafana-objstore-") for key, value in doc["data"].items()}
        assert len(provisioned) == 3
        assert files.isdisjoint(provisioned), "Grafana sidecars write all tenants to shared directories"
        files.update(provisioned)
        datasource = next(yaml.safe_load(value)["datasources"][0] for key, value in provisioned.items() if key.endswith(".yaml"))
        assert datasource["url"] == url
        assert datasource["uid"] not in uids
        uids.add(datasource["uid"])
        dashboards = [json.loads(value) for key, value in provisioned.items() if key.endswith(".json")]
        for dashboard in dashboards:
            # The bundled sidecar defaults place these in the same folder.
            assert dashboard["title"] not in titles
            assert tenant in dashboard["title"]
            assert dashboard["uid"] not in uids
            assert dashboard["templating"]["list"][0]["current"]["value"] == datasource["uid"]
            titles.add(dashboard["title"])
            uids.add(dashboard["uid"])
    assert len(files) == 6 and len(titles) == 4


@pytest.mark.parametrize("host,want", [(None, "http://127.0.0.1:32770"), ("docker.test.invalid", "http://docker.test.invalid:32770")])
def test_exporter_endpoint_uses_localhost_or_explicit_override(monkeypatch, host, want):
    # Only Docker's external command is stubbed; exercise the real URL construction.
    def published_port(*args, **kwargs):
        assert args == ("port", "test-container", "9598")
        return subprocess.CompletedProcess(args, 0, stdout="0.0.0.0:32770\n[::]:32770\n")

    monkeypatch.setattr(exporters, "docker", published_port)
    monkeypatch.delenv("TEST_DOCKER_HOST", raising=False)
    if host is not None:
        monkeypatch.setenv("TEST_DOCKER_HOST", host)
    assert exporters.endpoint("test-container", 9598) == want
