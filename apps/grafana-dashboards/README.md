# MinIO dashboards

The MinIO dashboards follow the metrics v2 endpoints configured in
`tfmodules/cwm_minio_tenant/metrics_app.tf`. Use a recent relative time range and
select the tenant's MinIO Prometheus data source. Bucket/operation variables use
v2 `bucket`/`api` labels. MinIO v3 metrics require a separate scrape/query migration;
changing dashboard names alone does not enable them.

The node and cluster endpoints repeat S3/network counters. Aggregate node counters
from `job="minio-job-node"` only. Each bucket endpoint repeats bucket metrics;
deduplicate `job`, `instance` and `pod` copies before summing rates/histograms.
Bucket inventory uses `max by (bucket)` rather than adding the replicas.

The provisioned Minio Debugging dashboard uses selectable MinIO and ingress data
sources rather than interactive-import `DS_*` placeholders. It defaults to the last
hour. Its ingress panels use the separate ingress Prometheus source; they require
those metrics and matching ingress labels there. Empty latency during an idle period
is different from a missing metric. Do not manufacture observations to fill gaps.

Validation:

```bash
python -m pytest -q tests/test_minio_dashboards.py
helm lint apps/grafana-dashboards --set minio.enabled=true --set minio.prometheusUrl=http://example:80
```

The regression fixture records metric names observed from healthy v2 scrapes on
2026-10-09; it contains no credentials, labels or sample values. Live query validation
is separate from rendering tests. Dashboard-only rollout updates ConfigMaps; it does
not require MinIO or Prometheus restarts or scrape changes. Publish the reviewed
revision and pin only the tenant dashboard application's revision through the normal
Terraform handoff. Avoid Argo sync or live ConfigMap replacement during load tests.
