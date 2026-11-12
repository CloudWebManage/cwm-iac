"""Evaluate the actual legacy scrape locals, without providers or Vault access."""
import json
from pathlib import Path
import subprocess

import pytest


@pytest.mark.parametrize("enabled", [True, False])
def test_tenant_scrape_configs_accept_enabled_and_disabled_metrics(tmp_path, enabled):
    source = (Path(__file__).resolve().parents[1] /
              "tfmodules/cwm_minio_tenant/metrics_app.tf").read_text()
    locals_block = "locals {" + source.split("\nlocals {", 1)[1].split('\nmodule "metrics_app"', 1)[0]
    # Replace only external data/resource references, retaining all real
    # conditional, merge, concat and relabel expressions under test.
    locals_block = locals_block.replace(
        "data.vault_kv_secret_v2.minio_tenant_main_mc_metrics_prometheus_config[0].data.config",
        'jsonencode({scrape_configs = [{bearer_token = "synthetic-token"}]})',
    ).replace("kubernetes_namespace.tenant.metadata[0].name", '"minio-tenant-test"')
    (tmp_path / "main.tf").write_text('''
variable "metrics" { type = bool }
variable "name" { default = "test" }
variable "cluster_name" { default = "test-cluster" }
''' + locals_block)
    result = subprocess.run(
        ["terraform", "console", "-no-color", f"-var=metrics={str(enabled).lower()}"],
        cwd=tmp_path,
        input="jsonencode({original = local.scrape_configs, tenant = concat(local.tenant_scrape_configs, [])})\n",
        text=True, capture_output=True, timeout=30,
    )
    # console can return zero while emitting local-evaluation errors on stderr.
    assert result.returncode == 0 and "Error:" not in result.stderr, result.stderr
    value = json.loads(json.loads(result.stdout))
    if not enabled:
        assert value == {"original": None, "tenant": []}
        return
    jobs = {job["job_name"]: job for job in value["tenant"]}
    assert set(jobs) == {"minio-audit-metrics", "cwm-minio-api", "minio-job-cluster",
                         "minio-job-node", "minio-job-bucket", "minio-job-resource"}
    for original in value["original"]:
        current = jobs[original["job_name"]]
        assert {key: item for key, item in current.items() if key != "relabel_configs"} == {
            key: item for key, item in original.items() if key != "relabel_configs"}
        relabels = current["relabel_configs"]
        assert relabels[:len(original.get("relabel_configs", []))] == original.get("relabel_configs", [])
        assert relabels[-3:] == [
            {"target_label": "cluster", "replacement": "test-cluster"},
            {"target_label": "tenant", "replacement": "test"},
            {"source_labels": ["__meta_kubernetes_pod_name"], "target_label": "pod", "regex": "(.+)"},
        ]
        port_filters = [rule for rule in relabels if rule.get("regex") == "minio;9000"]
        assert len(port_filters) == int(original["job_name"] in {
            "minio-job-node", "minio-job-bucket", "minio-job-resource"})
