"""Campaign monitor integration: private targets, actual producer metrics and active-run alerts."""
import json
import subprocess

import pytest
import yaml

from tests.containers import container
from tests.test_objstore_monitoring import ROOT, evaluate, render

TARGET = "10.20.30.40:9910"
RUN_ID = "campaign-test"


def profile(**monitoring):
    values = json.loads((ROOT / "docs/examples/objstore-load-test.tfvars.json").read_text())
    values["objstore_monitoring"] = {"enabled": True, "campaign_targets": [TARGET], "campaign_run_id": RUN_ID, **monitoring}
    return values


def prometheus_data(tmp_path, values):
    config = evaluate(tmp_path, values)
    docs = render(tmp_path, "minio-tenant-metrics", config["metrics"])
    return next(d["data"] for d in docs if "prometheus.yml" in d.get("data", {}))


def promtool(files, *command):
    with container("quay.io/prometheus/prometheus:v3.5.0", list(command), files, ["--entrypoint", "/bin/promtool"]) as identifier:
        result = subprocess.run(["docker", "start", "-a", identifier], text=True, capture_output=True)
        assert result.returncode == 0, result.stdout + result.stderr


def test_campaign_static_scrape_has_run_identity_and_private_destination_contract(tmp_path):
    data = prometheus_data(tmp_path, profile(campaign_targets=[TARGET, "[fd12:3456::40]:9910"]))
    config = yaml.safe_load(data["prometheus.yml"])
    job = next(j for j in config["scrape_configs"] if j["job_name"] == "objstore-campaign")
    assert job["static_configs"] == [{"targets": [TARGET, "[fd12:3456::40]:9910"], "labels": {"cluster": "test-cluster", "tenant": "test", "run_id": RUN_ID}}]
    assert job["scrape_interval"] == "15s" and job["scrape_timeout"] == "10s"
    assert job["metrics_path"] == "/metrics" and job["scheme"] == "http"
    assert job["follow_redirects"] is False and job["honor_labels"] is False
    assert job["sample_limit"] == 100000
    assert {r["action"] for r in job["metric_relabel_configs"]} == {"keep", "labelkeep"}
    files = {f"etc/config/{k}": v for k, v in data.items()}
    promtool(files, "check", "config", "--syntax-only", "/etc/config/prometheus.yml")
    promtool(files, "check", "rules", "/etc/config/alerting_rules.yml")


def test_no_campaign_targets_preserves_pipeline_only_defaults(tmp_path):
    values = profile()
    values["objstore_monitoring"] = {"enabled": True}
    data = prometheus_data(tmp_path, values)
    assert "objstore-campaign" not in {j["job_name"] for j in yaml.safe_load(data["prometheus.yml"])["scrape_configs"]}
    assert not any(r.get("alert", "").startswith("ObjstoreCampaign") for g in yaml.safe_load(data["alerting_rules.yml"])["groups"] for r in g["rules"])


@pytest.mark.parametrize("run_id", ["", " "])
def test_campaign_targets_require_run_id(tmp_path, run_id):
    with pytest.raises(subprocess.CalledProcessError):
        evaluate(tmp_path, profile(campaign_run_id=run_id))


@pytest.mark.parametrize("target", [
    "8.8.8.8:9910", "127.0.0.1:9910", "0.0.0.0:9910", "169.254.169.254:80",
    "10.1.2.256:9910", "10.1.2.3:0", "10.1.2.3:65536", "https://10.1.2.3:9910",
    "monitor.example:9910", "10.1.2.3:9910/metrics", "[::1]:9910", "[2001:4860::1]:9910",
])
def test_campaign_rejects_public_ambiguous_or_non_endpoint_destinations(tmp_path, target):
    with pytest.raises(subprocess.CalledProcessError):
        evaluate(tmp_path, profile(campaign_targets=[target]))


def test_campaign_rejects_duplicate_targets(tmp_path):
    with pytest.raises(subprocess.CalledProcessError):
        evaluate(tmp_path, profile(campaign_targets=[TARGET, TARGET]))


def test_campaign_alerts_evaluate_active_idle_missing_and_recovery_scenarios(tmp_path):
    data = prometheus_data(tmp_path, profile())
    rules = yaml.safe_load(data["alerting_rules.yml"])
    names = {r.get("alert") for g in rules["groups"] for r in g["rules"]}
    assert names >= {"ObjstoreCampaignTargetDown", "ObjstoreCampaignTargetMissing", "ObjstoreCampaignMonitorStale"}
    files = {f"etc/config/{k}": v for k, v in data.items()}
    files["tmp/campaign.test.yaml"] = (ROOT / "tests/objstore-campaign-alerts.test.yaml").read_text()
    promtool(files, "check", "rules", "/etc/config/alerting_rules.yml")
    promtool(files, "test", "rules", "/tmp/campaign.test.yaml")


def test_fresh_idle_snapshot_overrides_an_unavailable_monitors_old_running_flag(tmp_path):
    data = prometheus_data(tmp_path, profile(campaign_targets=[TARGET, "10.20.30.41:9910"]))
    tests = {
        "rule_files": ["/etc/config/alerting_rules.yml"], "evaluation_interval": "15s", "tests": [{
            "interval": "1m", "input_series": [
                {"series": 'cwm_objstore_loadtest_stage_status{job="objstore-campaign",cluster="test-cluster",tenant="test",run_id="campaign-test",instance="10.20.30.40:9910",stage="mixed",status="running"}', "values": "1+0x1 stale _x10"},
                {"series": 'cwm_objstore_loadtest_monitor_last_refresh_timestamp_seconds{job="objstore-campaign",cluster="test-cluster",tenant="test",run_id="campaign-test",instance="10.20.30.40:9910"}', "values": "1 60 stale _x10"},
                {"series": 'up{job="objstore-campaign",cluster="test-cluster",tenant="test",run_id="campaign-test",instance="10.20.30.40:9910"}', "values": "1 1 0+0x10"},
                {"series": 'cwm_objstore_loadtest_stage_status{job="objstore-campaign",cluster="test-cluster",tenant="test",run_id="campaign-test",instance="10.20.30.41:9910",stage="mixed",status="running"}', "values": "1 1 0+0x10"},
                {"series": 'cwm_objstore_loadtest_monitor_last_refresh_timestamp_seconds{job="objstore-campaign",cluster="test-cluster",tenant="test",run_id="campaign-test",instance="10.20.30.41:9910"}', "values": "1+60x12"},
                {"series": 'up{job="objstore-campaign",cluster="test-cluster",tenant="test",run_id="campaign-test",instance="10.20.30.41:9910"}', "values": "1+0x12"},
            ],
            "alert_rule_test": [{"eval_time": "8m", "alertname": name, "exp_alerts": []} for name in ("ObjstoreCampaignTargetDown", "ObjstoreCampaignTargetMissing", "ObjstoreCampaignMonitorStale")],
        }],
    }
    files = {f"etc/config/{k}": v for k, v in data.items()}
    files["tmp/multi-monitor.test.yaml"] = yaml.safe_dump(tests)
    promtool(files, "test", "rules", "/tmp/multi-monitor.test.yaml")


def test_campaign_dashboard_queries_use_actual_contract_samples(tmp_path):
    docs = render(tmp_path, "grafana-dashboards", {"minio": {"enabled": True, "objstoreMonitoring": True, "prometheusUrl": "http://test-prometheus:80", "namespaces": {"tenant": "minio-tenant-test"}}})
    dashboard = next(json.loads(v) for d in docs if d["metadata"]["name"].startswith("grafana-objstore-load-test-overview-") for v in d["data"].values())
    assert {v["name"] for v in dashboard["templating"]["list"]} >= {"run_id", "campaign_instance"}
    panels = {p["title"]: p for p in dashboard["panels"]}
    expectations = [
        ("Campaign request rate", 0, [{"labels": '{stage="mixed",operation="get_object"}', "value": 1}]),
        ("Successful verified GET throughput", 0, [{"labels": '{stage="mixed"}', "value": 921.6}]),
        ("Campaign error rate", 0, [{"labels": '{stage="mixed"}', "value": 0.1}]),
        ("Full-body GET latency p95 / p99", 0, [{"labels": '{stage="mixed"}', "value": 1.75}]),
        ("Full-body GET latency p95 / p99", 1, [{"labels": '{stage="mixed"}', "value": 2.35}]),
        ("Campaign stage status", 0, [{"labels": '{stage="mixed",status="running"}', "value": 1}]),
        ("Observed cohort state", 0, [{"labels": '{cohort="cold",state="cold"}', "value": 10}]),
        ("Last cohort observation age", 0, [{"labels": '{cohort="cold"}', "value": 180}]),
        ("Lifecycle completed objects by gate", 0, [{"labels": '{cohort="cold",gate="cold"}', "value": 10}]),
        ("Observed restore expiry bounds", 0, [{"labels": '{cohort="cold",bound="min"}', "value": 86400000}]),
        ("Campaign observed errors (cumulative)", 0, [{"labels": '{stage="mixed"}', "value": 30}]),
        ("Campaign error-rate history", 0, [{"labels": '{stage="mixed"}', "value": 2}]),
    ]
    fixtures = yaml.safe_load((ROOT / "tests/fixtures/objstore/campaign-series.yaml").read_text())
    checks, empty_checks = [], []
    for title, index, samples in expectations:
        query = panels[title]["targets"][index]["expr"]
        for key, value in {"$__rate_interval": "5m", "$cluster": "test-cluster", "$tenant": "test", "$run_id": RUN_ID, "$campaign_instance": TARGET}.items():
            query = query.replace(key, value)
        if title == "Full-body GET latency p95 / p99":
            # Compare quantile estimates to microsecond precision, avoiding the
            # floating-point cancellation in histogram interpolation (several ULPs).
            query = f"round(({query}), 0.000001)"
        checks.append({"expr": query, "eval_time": "5m", "exp_samples": samples})
        empty_checks.append({"expr": query, "eval_time": "5m", "exp_samples": []})
    tests = {"rule_files": ["/etc/config/alerting_rules.yml"], "evaluation_interval": "15s", "fuzzy_compare": True, "tests": [
        {"name": "actual monitor/report metric contract", "interval": "1m", "input_series": fixtures, "promql_expr_test": checks},
        {"name": "absent campaign metrics do not fabricate latency or state", "interval": "1m", "input_series": [], "promql_expr_test": empty_checks},
        {"name": "idle counters do not fabricate latency or an error ratio", "interval": "1m", "input_series": [{**s, "values": "0+0x10"} for s in fixtures], "promql_expr_test": empty_checks[2:5]},
        {"name": "requests without an errors series have zero error ratio", "interval": "1m", "input_series": [s for s in fixtures if not s["series"].startswith("cwm_objstore_loadtest_errors_total")], "promql_expr_test": [{**checks[2], "exp_samples": [{"labels": '{stage="mixed"}', "value": 0}]}]},
    ]}
    data = prometheus_data(tmp_path, profile())
    files = {f"etc/config/{k}": v for k, v in data.items()}
    files["tmp/dashboard.test.yaml"] = yaml.safe_dump(tests)
    promtool(files, "test", "rules", "/tmp/dashboard.test.yaml")
