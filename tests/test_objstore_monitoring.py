"""Offline contract tests: evaluate real Terraform locals, then render their charts."""
import json
from pathlib import Path
import re
import subprocess

import pytest
import yaml

from tests.containers import container, docker

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "tfmodules/cwm_minio_tenant"


def run(*args, cwd=ROOT, input=None):
    return subprocess.run(args, cwd=cwd, input=input, text=True, capture_output=True, check=True).stdout


def evaluate(tmp_path, overrides=None):
    # These files contain only inputs/locals: no providers, state, secrets or cloud calls.
    for name in ("variables.tf", "tierer.tf", "objstore_monitoring.tf", "objstore-alerts.yaml.tftpl"):
        (tmp_path / name).write_text((MODULE / name).read_text())
    values = {
        "name": "test", "cluster_name": "test-cluster", "metrics": True,
        "pools": {"one": {"servers": 2}, "two": {"servers": 1}},
        "tierer_config": {"low_hours": 72, "high_hours": 72, "low_threshold": 3, "high_threshold": 3},
    }
    values.update(overrides or {})
    (tmp_path / "terraform.tfvars.json").write_text(json.dumps(values))
    output = run("terraform", "console", input='jsonencode({tierer = local.tierer_values, sidecars = local.tierer_sidecars, metrics = local.objstore_metrics_values, pools = var.pools})\n', cwd=tmp_path)
    return json.loads(json.loads(output))


def render(tmp_path, chart, values, value_files=()):
    path = tmp_path / f"{chart}.yaml"
    path.write_text(yaml.safe_dump(values))
    files = [arg for file in (*value_files, path) for arg in ("-f", str(file))]
    return [doc for doc in yaml.safe_load_all(run("helm", "template", "test", str(ROOT / "apps" / chart), *files)) if doc]


def resource(docs, kind, name):
    return next(d for d in docs if d["kind"] == kind and d["metadata"]["name"] == name)


def tenant_values(config):
    return {**config["tierer"], "clusterName": "test-cluster", "low_tier_s3": {}, "tenant": {"tenant": {
        "name": "test", "configSecret": {"name": "existing", "existingSecret": True},
        "sideCars": config["sidecars"],
        "pools": [{"name": name, "servers": 1, "volumesPerServer": 1, "size": "10Gi", **pool} for name, pool in config["pools"].items()],
    }}}


def env(container):
    return {v["name"]: v["value"] for v in container["env"] if "value" in v}


def test_existing_policy_and_redis_defaults_with_singleton_rollouts(tmp_path):
    config = evaluate(tmp_path)
    docs = render(tmp_path, "minio-tenant", tenant_values(config))
    scanner = resource(docs, "Deployment", "tierer-server")
    redis = resource(docs, "Deployment", "tierer-redis")
    for deployment in (scanner, redis):
        assert deployment["spec"]["replicas"] == 1
        assert deployment["spec"]["strategy"] == {"type": "Recreate"}
    scanner_container = scanner["spec"]["template"]["spec"]["containers"][0]
    settings = env(scanner_container)
    assert {k: settings[k] for k in ("TIERER_MODE", "TIERER_APPLY", "TIERER_HIGH_INCLUDE_CURRENT", "TIERER_COVERAGE_ENABLED", "TIERER_CHUNK_SIZE", "ACCESS_RETENTION")} == {
        "TIERER_MODE": "apply", "TIERER_APPLY": "true", "TIERER_HIGH_INCLUDE_CURRENT": "true", "TIERER_COVERAGE_ENABLED": "false", "TIERER_CHUNK_SIZE": "69", "ACCESS_RETENTION": "77h",
    }
    assert not any(k.startswith("TIERER_DAILY_") for k in settings)
    containers = redis["spec"]["template"]["spec"]["containers"]
    assert len(containers) == 1
    assert containers[0]["command"] == ["redis-server", "--save", "60", "1", "--loglevel", "warning", "--appendonly", "no", "--appendfsync", "everysec", "--maxmemory-policy", "noeviction", "--maxmemory", "0"]
    updater = next(c for c in config["sidecars"]["containers"] if c["name"] == "cwm-minio-tierer-access-updater")
    assert updater["image"] == "ghcr.io/cloudwebmanage/cwm-minio-tierer:aa0cbe581d39be5f88c12c57f3d6d9075beea454"
    assert "cwmMinioTierer" not in config["tierer"]
    assert env(updater)["UPDATER_MAX_RECORDS"] == "1000000"
    assert env(updater)["UPDATER_QUEUE_SIZE"] == "128"
    assert "UPDATER_METRICS_LISTEN_ADDR" not in env(updater)
    assert config["metrics"]["prometheus"]["server"]["retention"] == "2d"


def test_enabled_profile_has_bounded_policy_separate_metrics_and_evaluated_rules(tmp_path):
    profile = json.loads((ROOT / "docs/examples/objstore-load-test.tfvars.json").read_text())
    config = evaluate(tmp_path, profile)
    docs = render(tmp_path, "minio-tenant", tenant_values(config))
    scanner = resource(docs, "Deployment", "tierer-server")["spec"]["template"]["spec"]["containers"][0]
    settings = env(scanner)
    assert settings["TIERER_MODE"] == "audit"
    assert settings["TIERER_APPLY"] == "false"
    assert settings["TIERER_HIGH_INCLUDE_CURRENT"] == "false"
    assert settings["TIERER_DAILY_TRANSITION_BYTES"] == "107374182400"
    assert settings["TIERER_COVERAGE_ENABLED"] == "true"
    assert {k: settings[k] for k in ("TIERER_COVERAGE_TEMPLATE", "TIERER_COVERAGE_VALUE", "TIERER_RESTORE_DAYS", "TIERER_EXCLUDE_BUCKETS", "TIERER_EXCLUDE_BUCKET_PREFIXES", "TIERER_CHUNK_SIZE")} == {
        "TIERER_COVERAGE_TEMPLATE": "cwm-test-coverage:2006-01-02T15", "TIERER_COVERAGE_VALUE": "complete", "TIERER_RESTORE_DAYS": "1", "TIERER_EXCLUDE_BUCKETS": "control", "TIERER_EXCLUDE_BUCKET_PREFIXES": "system-", "TIERER_CHUNK_SIZE": "64",
    }
    assert len([v for k, v in settings.items() if k.startswith("TIERER_DAILY_") and int(v) > 0]) == 4
    redis = resource(docs, "Deployment", "tierer-redis")["spec"]["template"]["spec"]["containers"]
    assert redis[0]["command"][-8:] == ["--appendonly", "yes", "--appendfsync", "everysec", "--maxmemory-policy", "noeviction", "--maxmemory", "1073741824"]
    assert redis[1]["image"] == "oliver006/redis_exporter:v1.80.1"
    assert scanner["resources"]["limits"]["memory"] == "512Mi"
    tenant = resource(docs, "Tenant", "test")
    assert sum(pool["servers"] for pool in tenant["spec"]["pools"]) == 3
    updater = next(c for c in tenant["spec"]["sideCars"]["containers"] if c["name"] == "cwm-minio-tierer-access-updater")
    assert updater["image"] == scanner["image"] == profile["minio_tierer_image"]
    assert env(updater)["UPDATER_LISTEN_ADDR"] == "127.0.0.1:8921"
    assert env(updater)["UPDATER_METRICS_LISTEN_ADDR"] == "0.0.0.0:8922"
    assert env(updater)["UPDATER_MAX_RECORDS"] == "1000"
    assert env(updater)["UPDATER_BATCH_MAX_EVENTS"] == "5000"
    assert [p["containerPort"] for p in updater["ports"]] == [8922]
    metrics = render(tmp_path, "minio-tenant-metrics", config["metrics"])
    prometheus_deployment = next(d for d in metrics if d["kind"] == "Deployment")
    assert any("--storage.tsdb.retention.time=21d" in c.get("args", []) for c in prometheus_deployment["spec"]["template"]["spec"]["containers"])
    prometheus_pvc = next(d for d in metrics if d["kind"] == "PersistentVolumeClaim")
    assert prometheus_pvc["spec"]["resources"]["requests"]["storage"] == "150Gi"
    prom_cm = next(d for d in metrics if d["kind"] == "ConfigMap" and "prometheus.yml" in d.get("data", {}))
    prom = yaml.safe_load(prom_cm["data"]["prometheus.yml"])
    rules = yaml.safe_load(prom_cm["data"]["alerting_rules.yml"])
    assert "/etc/config/alerting_rules.yml" in prom["rule_files"]
    assert len(rules["groups"][0]["rules"]) >= 10
    assert prom["alerting"]["alertmanagers"][0]["static_configs"][0]["targets"] == ["monitoring-kube-prometheus-alertmanager.monitoring.svc:9093"]
    assert prom["global"]["evaluation_interval"] == "15s"
    assert config["metrics"]["prometheus"]["server"]["retention"] == "21d"
    jobs = {j["job_name"]: j for j in prom["scrape_configs"]}
    assert set(jobs) >= {"objstore-tierer", "objstore-updater", "objstore-vector", "objstore-redis"}
    for name in ("objstore-tierer", "objstore-updater", "objstore-vector", "objstore-redis"):
        assert jobs[name]["scrape_interval"] == "15s"
        labels = {r.get("target_label") for r in jobs[name]["relabel_configs"]}
        assert labels >= {"cluster", "tenant", "pod"}
    # Persist only synthetic rendered config for promtool validation, never real tenant credentials.
    for name, contents in prom_cm["data"].items():
        if name.endswith((".yml", ".yaml")) or name in ("rules", "alerts"):
            (tmp_path / name).write_text(contents)


@pytest.mark.parametrize("setting,value", [("daily_transition_bytes", "0"), ("daily_restore_attempts", "-1"), ("daily_restore_bytes", "1.5"), ("chunk_size", "100"), ("mode", "invalid")])
def test_invalid_policy_fails_before_deployment(tmp_path, setting, value):
    with pytest.raises(subprocess.CalledProcessError):
        config = evaluate(tmp_path, {"tierer_config": {"low_hours": "72", "high_hours": "72", "low_threshold": "3", "high_threshold": "3", setting: value}})
        render(tmp_path, "minio-tenant", tenant_values(config))


def test_monitoring_rejects_legacy_updater_image(tmp_path):
    with pytest.raises(subprocess.CalledProcessError):
        evaluate(tmp_path, {"objstore_monitoring": {"enabled": True}})


def test_apply_profile_delays_and_disabled_probes_reach_scanner(tmp_path):
    config = evaluate(tmp_path, {"tierer_config": {
        "low_hours": "1", "high_hours": "1", "low_threshold": "3", "high_threshold": "3",
        "completion_delay": "10m", "retry_delay": "15s", "probes_enabled": "false", "restore_days": "2",
        "daily_transition_attempts": "100", "daily_transition_bytes": "1000000",
        "daily_restore_attempts": "200", "daily_restore_bytes": "2000000",
    }})
    scanner = resource(render(tmp_path, "minio-tenant", tenant_values(config)), "Deployment", "tierer-server")["spec"]["template"]["spec"]["containers"][0]
    assert "livenessProbe" not in scanner and "readinessProbe" not in scanner
    settings = env(scanner)
    assert settings["TIERER_MODE"] == "apply" and settings["TIERER_APPLY"] == "true"
    assert settings["TIERER_COMPLETION_DELAY"] == "10m"
    assert settings["TIERER_RETRY_DELAY"] == "15s"
    assert settings["TIERER_RESTORE_DAYS"] == "2"
    assert settings["TIERER_CHUNK_SIZE"] == "5000"


@pytest.mark.parametrize("overrides", [
    {"coverage_enabled": "true"}, {"exclude_buckets": "one,one"}, {"exclude_bucket_prefixes": "x, y"},
    {"mode": "apply", "apply": "false"},
])
def test_helm_rejects_incoherent_scanner_policy(tmp_path, overrides):
    config = evaluate(tmp_path)
    values = tenant_values(config)
    values["tierer"].update(overrides)
    with pytest.raises(subprocess.CalledProcessError):
        render(tmp_path, "minio-tenant", values)


def test_default_charts_render_and_monitoring_is_opt_in(tmp_path):
    for chart in ("minio-tenant", "minio-tenant-metrics", "grafana-dashboards"):
        values = {"tenant": {"tenant": {"name": "test", "configSecret": {"name": "existing", "existingSecret": True}}}} if chart == "minio-tenant" else {}
        docs = render(tmp_path, chart, values)
        assert not any("objstore" in d["metadata"]["name"] for d in docs)
    metrics = render(tmp_path, "minio-tenant-metrics", {})
    deployment = next(d for d in metrics if d["kind"] == "Deployment")
    assert "--storage.tsdb.retention.time=2d" in deployment["spec"]["template"]["spec"]["containers"][0]["args"] or any(
        "--storage.tsdb.retention.time=2d" in c.get("args", []) for c in deployment["spec"]["template"]["spec"]["containers"]
    )


def test_existing_vmagent_values_still_enable_remote_write(tmp_path):
    docs = render(tmp_path, "minio-tenant-metrics", {"vmagent": {
        "clusterLabel": "test-cluster", "tenantLabel": "test",
        "remoteWrite": {"baseUrl": "https://metrics.invalid", "username": "", "password": ""},
    }})
    deployment = resource(docs, "Deployment", "vmagent")
    assert "-remoteWrite.url=https://metrics.invalid/api/v1/write" in deployment["spec"]["template"]["spec"]["containers"][0]["args"]


def test_prometheus_config_rules_and_dashboard_promql(tmp_path):
    profile = json.loads((ROOT / "docs/examples/objstore-load-test.tfvars.json").read_text())
    config = evaluate(tmp_path, profile)
    docs = render(tmp_path, "minio-tenant-metrics", config["metrics"])
    data = next(d["data"] for d in docs if "prometheus.yml" in d.get("data", {}))
    files = {f"etc/config/{k}": v for k, v in data.items()}
    files["tmp/alerts.test.yaml"] = (ROOT / "tests/objstore-alerts.test.yaml").read_text()
    dashboards = render(tmp_path, "grafana-dashboards", {"minio": {"enabled": True, "objstoreMonitoring": True, "prometheusUrl": "http://tenant-prometheus:80", "namespaces": {"tenant": "minio-tenant-test"}}})
    datasource = next(yaml.safe_load(value)["datasources"][0] for d in dashboards if d["metadata"]["name"].startswith("grafana-objstore-datasource-") for value in d["data"].values())
    assert datasource["url"] == "http://tenant-prometheus:80"
    dashboards = [json.loads(v) for d in dashboards if d["metadata"]["name"].startswith("grafana-objstore-") for k, v in d["data"].items() if k.endswith(".json")]
    assert all(d["templating"]["list"][0]["current"]["value"] == datasource["uid"] for d in dashboards)
    assert {d["title"] for d in dashboards} == {"Objstore Load Test Overview - minio-tenant-test", "Tiering Pipeline - minio-tenant-test"}
    assert len({d["uid"] for d in dashboards}) == 2
    expressions = [t["expr"].replace("$__rate_interval", "5m").replace("$cluster", "test-cluster").replace("$tenant", "test") for d in dashboards for p in d["panels"] for t in p.get("targets", [])]
    files["tmp/dashboard-expressions.yml"] = yaml.safe_dump({"groups": [{"name": "dashboard-syntax", "rules": [{"record": f"dashboard_panel_{i}", "expr": expr} for i, expr in enumerate(expressions)]}]})
    for command in (
        ["check", "config", "--syntax-only", "/etc/config/prometheus.yml"],
        ["check", "rules", "/etc/config/alerting_rules.yml", "/tmp/dashboard-expressions.yml"],
        ["test", "rules", "/tmp/alerts.test.yaml"],
    ):
        with container("quay.io/prometheus/prometheus:v3.5.0", command, files, ["--entrypoint", "/bin/promtool"]) as identifier:
            result = subprocess.run(["docker", "start", "-a", identifier], text=True, capture_output=True)
            assert result.returncode == 0, result.stdout + result.stderr


def test_discovery_keeps_one_target_per_container_port_and_pod(tmp_path):
    profile = json.loads((ROOT / "docs/examples/objstore-load-test.tfvars.json").read_text())
    config = evaluate(tmp_path, profile)
    jobs = config["metrics"]["prometheus"]["serverFiles"]["prometheus.yml"]["scrape_configs"]
    # Kubernetes pod discovery candidates include every port in a multi-container pod.
    candidates = [
        ("minio", "http-minio", 9000), ("minio", "http-console", 9090),
        ("cwm-iac-minio-log-metrics", "audit-metrics", 8799),
        ("cwm-iac-minio-log-metrics", "vector-metrics", 9598),
        ("cwm-minio-tierer-access-updater", "updater-metrics", 8922),
        ("tierer-server", "tierer-metrics", 8081),
        ("tierer-redis", "redis", 6379), ("redis-exporter", "redis-metrics", 9121),
    ]
    expected = {"objstore-updater": 8922, "objstore-vector": 9598, "objstore-tierer": 8081, "objstore-redis": 9121}
    for job in jobs:
        if "kubernetes_sd_configs" not in job:
            continue
        kept = []
        for name, port_name, port in candidates:
            labels = {"__meta_kubernetes_pod_container_name": name, "__meta_kubernetes_pod_container_port_name": port_name, "__meta_kubernetes_pod_phase": "Running", "__meta_kubernetes_pod_container_init": "false"}
            for rule in job["relabel_configs"]:
                value = ";".join(labels.get(label, "") for label in rule.get("source_labels", []))
                match = re.fullmatch(rule.get("regex", "(.*)"), value) is not None
                if (rule.get("action") == "keep" and not match) or (rule.get("action") == "drop" and match):
                    break
            else:
                kept.append(port)
        assert kept == [expected[job["job_name"]]]


@pytest.mark.parametrize("overrides", [
    {"updater_queue_size": "0"}, {"updater_max_body_bytes": "1073741825"},
    {"updater_max_records": "5001", "updater_batch_max_events": "5000"},
    {"completion_delay": "0s"}, {"unknown_setting": "true"},
])
def test_rejects_unbounded_or_invalid_updater_settings(tmp_path, overrides):
    with pytest.raises(subprocess.CalledProcessError):
        evaluate(tmp_path, {"tierer_config": {"low_hours": "72", "high_hours": "72", "low_threshold": "3", "high_threshold": "3", **overrides}})
