"""Producer-shaped R4/R5/R6 regressions using rendered rules, panels and inputs."""
import json
import subprocess

import pytest
import yaml

from tests.test_objstore_campaign import TARGET, RUN_ID, profile, prometheus_data, promtool
from tests.test_objstore_monitoring import evaluate, render

IDENTITY = f'job="objstore-campaign",cluster="test-cluster",tenant="test",run_id="{RUN_ID}",instance="{TARGET}"'
SECOND_TARGET = "10.20.30.41:9910"


def panels(tmp_path):
    docs = render(tmp_path, "grafana-dashboards", {"minio": {"enabled": True, "objstoreMonitoring": True, "prometheusUrl": "http://test-prometheus:80", "namespaces": {"tenant": "minio-tenant-test"}}})
    dashboard = next(json.loads(v) for d in docs if d["metadata"]["name"].startswith("grafana-objstore-load-test-overview-") for v in d["data"].values())
    return {p["title"]: p for p in dashboard["panels"]}


def expression(panel):
    query = panel["targets"][0]["expr"]
    for key, value in {"$__rate_interval": "5m", "$cluster": "test-cluster", "$tenant": "test", "$run_id": RUN_ID, "$campaign_instance": TARGET}.items():
        query = query.replace(key, value)
    return query


def rule_test(tmp_path, tests, targets=None):
    data = prometheus_data(tmp_path, profile(campaign_targets=targets or [TARGET]))
    files = {f"etc/config/{k}": v for k, v in data.items()}
    files["tmp/review.test.yaml"] = yaml.safe_dump({
        "rule_files": ["/etc/config/alerting_rules.yml"], "evaluation_interval": "15s",
        "tests": tests,
    })
    promtool(files, "test", "rules", "/tmp/review.test.yaml")


def request_series(values):
    return {"series": f'cwm_objstore_loadtest_requests_total{{{IDENTITY},stage="mixed",operation="get_object",size="1024"}}', "values": values}


def error_series(values, error="ReadTimeoutError"):
    return {"series": f'cwm_objstore_loadtest_errors_total{{{IDENTITY},stage="mixed",operation="get_object",size="1024",error="{error}"}}', "values": values}


def expected(query, at, value):
    return {"expr": query, "eval_time": at, "exp_samples": [] if value is None else [{"labels": '{stage="mixed"}', "value": value}]}


def test_first_sparse_error_and_new_error_labels_are_not_lost_from_rate(tmp_path):
    query = expression(panels(tmp_path)["Campaign error rate"])
    rule_test(tmp_path, [
        {"name": "first error arrives as one, not a preinitialized zero", "interval": "1m",
         "input_series": [request_series("1+60x10"), error_series("_ _ 1+0x8")],
         "promql_expr_test": [expected(f"({query}) > bool 0", "5m", 1)]},
        {"name": "another label combination also starts above zero", "interval": "1m",
         "input_series": [request_series("0+60x10"), error_series("_ _ 1+0x8"), error_series("_ _ _ _ 2+0x6", "SlowDown")],
         "promql_expr_test": [expected(f"({query}) > bool 0", "5m", 1)]},
        {"name": "isolated failure stops the traffic stage", "interval": "1m",
         "input_series": [request_series("0 60 121+0x8"), error_series("_ _ 1+0x8")],
         "promql_expr_test": [expected(f"({query}) > bool 0", "5m", 1), expected(query, "8m", None)]},
    ])


def test_cumulative_errors_and_rate_history_are_truthful_before_and_after_warmup(tmp_path):
    dashboard = panels(tmp_path)
    cumulative = expression(dashboard["Campaign observed errors (cumulative)"])
    ratio = expression(dashboard["Campaign error rate"])
    history = expression(dashboard["Campaign error-rate history"])
    rule_test(tmp_path, [
        {"name": "already-positive first snapshot has no preceding rate history", "interval": "1m",
         "input_series": [request_series("_ _ 120+60x8"), error_series("_ _ 1+0x8")],
         "promql_expr_test": [
             expected(cumulative, "2m", 1), expected(cumulative, "5m", 1),
             expected(ratio, "2m", None), expected(ratio, "5m", None),
             expected(history, "2m", 0), expected(history, "5m", 0),
             expected(ratio, "8m", 0), expected(cumulative, "8m", 1), expected(history, "8m", 2),
         ]},
        {"name": "no error series is legitimately zero only with request evidence", "interval": "1m",
         "input_series": [request_series("0+60x10")],
         "promql_expr_test": [expected(cumulative, "2m", 0), expected(ratio, "2m", None), expected(history, "2m", 0), expected(ratio, "5m", 0), expected(history, "5m", 2)]},
        {"name": "no campaign evidence is no data, not zero", "interval": "1m", "input_series": [],
         "promql_expr_test": [expected(cumulative, "5m", None), expected(ratio, "5m", None), expected(history, "5m", None)]},
        {"name": "stopped traffic retains the error and shows an idle window", "interval": "1m",
         "input_series": [request_series("0 60 121+0x8"), error_series("_ _ 1+0x8")],
         "promql_expr_test": [expected(cumulative, "8m", 1), expected(ratio, "8m", None), expected(history, "8m", 1)]},
        {"name": "a gap requires a complete new window, without hiding cumulative errors", "interval": "1m",
         "input_series": [request_series("0+60x3 stale _ 360+60x10"), error_series("_ _ 1 1 stale _ 1+0x10")],
         "promql_expr_test": [expected(cumulative, "8m", 1), expected(ratio, "8m", None), expected(history, "8m", 0), expected(ratio, "11m", 0), expected(history, "11m", 2)]},
    ])


@pytest.mark.parametrize("peer_refresh", ["current", "retained"])
@pytest.mark.parametrize("active_refresh", ["absent", "retained", "stale"])
def test_active_targets_missing_or_stale_refresh_are_not_disarmed_by_idle_peers(tmp_path, peer_refresh, active_refresh):
    other = IDENTITY.replace(TARGET, SECOND_TARGET)
    series = [
        {"series": f'cwm_objstore_loadtest_stage_status{{{IDENTITY},stage="mixed",status="running"}}', "values": "0+0x1 stale _x12" if peer_refresh == "retained" else "0+0x14"},
        {"series": f'cwm_objstore_loadtest_monitor_last_refresh_timestamp_seconds{{{IDENTITY}}}', "values": "1 60 stale _x12" if peer_refresh == "retained" else "1+60x14"},
        {"series": f'up{{{IDENTITY}}}', "values": "1 1 0+0x12" if peer_refresh == "retained" else "1+0x14"},
        {"series": f'cwm_objstore_loadtest_stage_status{{{other},stage="mixed",status="running"}}', "values": "0 0 1+0x12"},
        {"series": f'up{{{other}}}', "values": "1+0x14"},
    ]
    if active_refresh != "absent":
        series.append({"series": f'cwm_objstore_loadtest_monitor_last_refresh_timestamp_seconds{{{other}}}', "values": "1 60 stale _x12" if active_refresh == "retained" else "1 60+0x13"})
    rule_test(tmp_path, [{"interval": "1m", "input_series": series, "promql_expr_test": [{
        "expr": f'sum(cwm_objstore_loadtest:run_active{{cluster="test-cluster",tenant="test",run_id="{RUN_ID}"}})',
        "eval_time": "8m", "exp_samples": [{"labels": "{}", "value": 1}],
    }], "alert_rule_test": [{
        "eval_time": "8m", "alertname": "ObjstoreCampaignMonitorStale", "exp_alerts": [{
            "exp_labels": {"job": "objstore-campaign", "cluster": "test-cluster", "tenant": "test", "run_id": RUN_ID, "instance": SECOND_TARGET, "severity": "warning"},
            "exp_annotations": {"summary": "Active campaign monitor snapshot is stale or missing"},
        }],
    }]}], targets=[TARGET, SECOND_TARGET])


def test_idle_target_missing_refresh_does_not_inherit_an_active_peers_alert(tmp_path):
    other = IDENTITY.replace(TARGET, SECOND_TARGET)
    rule_test(tmp_path, [{"interval": "1m", "input_series": [
        {"series": f'cwm_objstore_loadtest_stage_status{{{IDENTITY},stage="mixed",status="running"}}', "values": "1+0x12"},
        {"series": f'cwm_objstore_loadtest_monitor_last_refresh_timestamp_seconds{{{IDENTITY}}}', "values": "1+60x12"},
        {"series": f'up{{{IDENTITY}}}', "values": "1+0x12"},
        {"series": f'cwm_objstore_loadtest_stage_status{{{other},stage="mixed",status="running"}}', "values": "0+0x12"},
        {"series": f'up{{{other}}}', "values": "1+0x12"},
    ], "alert_rule_test": [{"eval_time": "8m", "alertname": "ObjstoreCampaignMonitorStale", "exp_alerts": []}]}], targets=[TARGET, SECOND_TARGET])


@pytest.mark.parametrize("target", ["[fd::1]:9910", "[fc::1]:9910", "[fbff::1]:9910", "[fe00::1]:9910"])
def test_ipv6_target_must_actually_belong_to_ula(tmp_path, target):
    with pytest.raises(subprocess.CalledProcessError):
        evaluate(tmp_path, profile(campaign_targets=[target]))


@pytest.mark.parametrize("target", ["[fc00::1]:9910", "[fcff::1]:9910", "[fd00::1]:9910", "[fdff::1]:9910", "[fd12:3456::40]:9910"])
def test_ipv6_ula_boundary_and_existing_operator_addresses_remain_valid(tmp_path, target):
    config = evaluate(tmp_path, profile(campaign_targets=[target]))
    job = next(j for j in config["metrics"]["prometheus"]["serverFiles"]["prometheus.yml"]["scrape_configs"] if j["job_name"] == "objstore-campaign")
    assert job["static_configs"][0]["targets"] == [target]
