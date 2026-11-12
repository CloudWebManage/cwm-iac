# Objstore load-test configuration and monitoring

This profile uses the existing tenant Prometheus and the existing monitoring
Grafana/Alertmanager. It adds pipeline collection at **15 seconds**, evaluated
alerts, and two dashboards. It does not deploy a campaign generator or a second
metrics backend. The opt-in example retains raw samples for **21 days**; existing
callers retain the **2-day** default.

## Integration and image contract

Configure the caller of `tfmodules/cwm_minio_tenant`. The example
[`examples/objstore-load-test.tfvars.json`](examples/objstore-load-test.tfvars.json)
contains module **input values**, not a drop-in root configuration: forward these
arguments from the root module explicitly. The example is intentionally in audit
mode and contains image-tag placeholders that must be replaced before deployment.
Use Terraform >= 1.9 (cross-variable input validation), Helm 3 and Python/uv.

* `minio_tierer_image` is an **optional explicit shared scanner and redis-updater
  image**, default **`null`**. When omitted/null, Terraform emits **no scanner
  image override**: the existing `versions["cwm-minio-tierer"] = "config/..."`
  value-file image remains selected. Without a config-file image, the chart uses
  `ghcr.io/cloudwebmanage/cwm-minio-tierer:34ef901cf197b7479e25714184a68d84ca0d0943`,
  which supports disabled coverage and omitted/unlimited apply budgets. The
  updater retains its existing `aa0cbe581d39be5f88c12c57f3d6d9075beea454` fallback.
* Only an explicit nonempty `minio_tierer_image` writes both
  `cwmMinioTierer.tierer.image` and
  `tenant.tenant.sideCars.containers[name=cwm-minio-tierer-access-updater].image`
  in `apps/minio-tenant`. This intentional shared override takes precedence over
  the scanner config file. Select it to integrate a new updater/scanner build;
  updating the scanner config file alone does not select a new updater image.
* Monitoring **requires a newly built** `cwm-minio-tierer` image containing both
  binaries and the Go `UPDATER_METRICS_LISTEN_ADDR` implementation. Omitted/null,
  empty, and both known pre-monitoring image values above are rejected when
  enabling the profile; selecting another tag is not proof of its contents. The
  scanner histogram must include finite buckets through 86400 seconds.
* `log_metrics_sidecar_image` must be a new build of
  `docker/minio-log-metrics/Dockerfile` from this revision. Its base is
  `timberio/vector:0.51.1-distroless-static`. The known old default is rejected for
  monitoring. A new image is also required when enabling the Vector filters alone.
* `objstore_monitoring.enabled = true` requires `metrics = true`,
  `tierer_redis_config.exporter_enabled = true`, and both explicit new images.
* Select this IaC/chart revision for **all three** existing Argo CD applications:
  `versions["cwm-iac-minio-tenant-<name>"]`,
  `metrics_app_target_revision`, and
  `versions["cwm-iac-minio-tenant-<name>-grafana-dashboards"]`.

The updater ingestion listener remains **127.0.0.1:8921**. Only monitoring enables
`UPDATER_METRICS_LISTEN_ADDR=0.0.0.0:8922` and declares `updater-metrics:8922`.
The new Go listener serves metrics/health separately from ingestion. No Service,
Ingress, or container port exposes 8921. Vector posts only to loopback 8921.

## Exact `tierer_config` contract

`tierer_config` is a flat `map(string)`; Terraform converts scalar numeric/bool
values to strings. Unknown keys are rejected. The four original policy inputs
remain required; the prior empty map default was not a usable configuration.
Unless stated otherwise, `tierer_config.<key>` maps to Helm `tierer.<key>` in
`apps/minio-tenant`, then to the listed scanner environment variable.

| Input key | Default for existing callers | Environment / behavior |
|---|---|---|
| `low_hours` | required | `TIERER_LOW_WINDOW_HOURS` |
| `low_threshold` | required | `TIERER_LOW_THRESHOLD` |
| `high_hours` | required | `TIERER_HIGH_WINDOW_HOURS` |
| `high_threshold` | required | `TIERER_HIGH_THRESHOLD` |
| `mode` | `apply` | `TIERER_MODE`, `audit` or `apply` |
| `apply` | `true` | `TIERER_APPLY`; apply mode requires true |
| `high_include_current` | `true` | `TIERER_HIGH_INCLUDE_CURRENT` |
| `restore_days` | `1` | `TIERER_RESTORE_DAYS`, positive MinIO calendar-day value |
| `coverage_enabled` | `false` | `TIERER_COVERAGE_ENABLED` |
| `coverage_template` | empty | `TIERER_COVERAGE_TEMPLATE`, hour-varying Go time-format key |
| `coverage_value` | empty | `TIERER_COVERAGE_VALUE`, exact complete value |
| `daily_transition_attempts` | empty / omitted env / unlimited | `TIERER_DAILY_TRANSITION_ATTEMPTS` |
| `daily_transition_bytes` | empty / omitted env / unlimited | `TIERER_DAILY_TRANSITION_BYTES` |
| `daily_restore_attempts` | empty / omitted env / unlimited | `TIERER_DAILY_RESTORE_ATTEMPTS` |
| `daily_restore_bytes` | empty / omitted env / unlimited | `TIERER_DAILY_RESTORE_BYTES` |
| `exclude_buckets` | empty | `TIERER_EXCLUDE_BUCKETS`, exact comma-separated names |
| `exclude_bucket_prefixes` | empty | `TIERER_EXCLUDE_BUCKET_PREFIXES`, exact comma-separated prefixes |
| `chunk_size` | `floor(10000/(low_hours+high_hours))` | `TIERER_CHUNK_SIZE` |
| `completion_delay` | `5m` | `TIERER_COMPLETION_DELAY` |
| `retry_delay` | `30s` | `TIERER_RETRY_DELAY` |
| `probes_enabled` | `true` | Helm HTTP `/livez` and `/readyz` probes on 8081; no env |
| `updater_max_body_bytes` | `1073741824` | updater `UPDATER_MAX_BODY_BYTES` |
| `updater_max_records` | `1000000` | updater `UPDATER_MAX_RECORDS` |
| `updater_queue_size` | `128` | updater `UPDATER_QUEUE_SIZE` |
| `updater_batch_max_events` | `1000000` | updater `UPDATER_BATCH_MAX_EVENTS` |
| `updater_batch_max_keys` | `1000000` | updater `UPDATER_BATCH_MAX_KEYS` |
| `updater_batch_max_wait` | `50ms` | updater `UPDATER_BATCH_MAX_WAIT` |

The `updater_*` inputs map directly to
`tenant.tenant.sideCars.containers[name=cwm-minio-tierer-access-updater].env`;
they are not stored under Helm `tierer`. Scanner and updater both receive
`ACCESS_RETENTION = (max(low_hours, high_hours)+5)h`. Marker key/value remain
`cwm-tier` / `low`, matching the lifecycle integration.

Daily limits, when set, must be decimal **positive int64 integers**. The test
example sets all four finite limits. Unset limits deliberately preserve legacy
unlimited behavior; enabling monitoring does not change mutation policy.
`chunk_size*(low_hours+high_hours)` cannot exceed 10000. Exclusions cannot contain
empty entries, surrounding whitespace or duplicates. Coverage requires nonempty
template/value; the binary additionally validates the Go time format. This IaC
does not create coverage records: the example's `cwm-test-coverage:2006-01-02T15`
contract needs a producer that writes `complete` only for complete UTC hours.

Updater counts are positive and at most 1000000; body bytes are at most 1 GiB.
One request must fit both batch limits. Vector sends at most 1000 events / 900000
encoded bytes per HTTP batch. Keep updater limits compatible. Vector's request
timeout is 720s, and the Go updater computes a safe write timeout from queue size,
batch wait, 15s body-read budget and 5s Redis timeout. The default worst-case
acknowledgement budget is `15s + (128+1)*(50ms+5s) = 666.45s`. If increasing the
queue or wait, ensure that budget still fits the Vector timeout; changing just
the queue can create client timeouts and replayed requests. The test profile
reduces per-request/per-batch limits without changing that timeout budget.

## Redis, resources and Vector settings

`tierer_resources` maps to `tierer.resources`; `updater_resources` and
`vector_resources` map to their named sidecar `resources`. Each accepts
`{requests = map(string), limits = map(string)}`, defaulting to empty maps.
The sample sizes are initial test allocations, not established capacity limits.

`tierer_redis_config` maps field-for-field to Helm `tiererRedis`:

| Field | Default | Rendered behavior |
|---|---|---|
| `appendonly` | `false` | Redis `--appendonly no` (`yes` when enabled) |
| `appendfsync` | `everysec` | `--appendfsync`, accepts `always`, `everysec`, `no` |
| `maxmemory_policy` | `noeviction` | `--maxmemory-policy`; standard Redis eviction policies accepted |
| `maxmemory` | `"0"` | `--maxmemory`, Redis size syntax; 0 means unlimited |
| `resources` | empty requests/limits | Redis resources |
| `exporter_enabled` | `false` | Add exporter sidecar to Redis pod |
| `exporter_image` | `oliver006/redis_exporter:v1.80.1` | Pinned exporter image |
| `exporter_resources` | empty requests/limits | Exporter resources |

The existing `--save 60 1 --loglevel warning`, Redis image, PVC name and `/data`
mount are retained. Both Redis and the singleton scanner use **Recreate**. Redis
rollout has downtime; the disk-backed Vector queue absorbs a bounded outage.
Recreate prevents overlapping Deployment replicas during a normal rollout; it
does not add distributed leader election for a force-deleted or partitioned pod.

Enabling AOF on an **existing RDB-only PVC needs a data-preserving Redis migration**,
not just a blind restart with a new flag. Use the profile on fresh test Redis or
carry out a separately verified RDB-to-AOF migration with a recoverable backup.
Control state includes scan cursors and daily budgets as well as access counts.
Leave memory headroom above maxmemory for AOF/RDB forks and client buffers.

`vector_access_config` fields:

| Field | Default | Sidecar env / behavior |
|---|---|---|
| `success_only` | `false` | `CWM_ACCESS_SUCCESS_ONLY`, string true/false |
| `exclude_tierer_identity` | `false` | When true, add `CWM_TIERER_ACCESS_KEY` via optional Secret ref |
| `tierer_identity_secret_name` | `cwm-minio-api-tenant-creds` | Secret name for excluded identity |
| `tierer_identity_secret_key` | `accesskey` | Secret key for excluded identity |

Vector looks up env at runtime using fallible `get_env_var(...) ?? ...`; missing
env or an absent optional Secret does not prevent startup. Empty identity means
no exclusion. A configured identity is matched exactly against **either**
`.accessKey` or `.parentUser`, including STS events. Prefer a dedicated tierer
identity; excluding a shared application identity excludes its reads too. No
credential value is stored in this example or in generated test artifacts.

Success-only access records require `.api.name == "GetObject"` and
`.api.statusCode` equal to **200 or 206**, as a number or numeric string. 304,
errors, malformed/missing status are excluded. Without the env setting (or with
false), the original status-independent GetObject counting is retained.
The filters affect only the Redis access stream; existing audit accounting
metrics remain unchanged. Each accepted output remains `{bucket, object}` NDJSON.

The updated Vector image exports `internal_metrics` at **9598/metrics**, separate
from audit accounting at **8799/metrics**. The internal source interval is 15s.
This endpoint exists in the updated image; tenant scraping is opt-in.

## Prometheus configuration and expected targets

`metrics_retention` maps to `apps/minio-tenant-metrics` →
`prometheus.server.retention`, default `2d`, test `21d` (positive integer h/d/w).
`metrics_storage_size` maps to `prometheus.server.persistentVolume.size`, default
`50Gi`, test `150Gi`. Retention is a time limit, not a storage sizing guarantee;
size for the observed raw-series rate before an 8–10 day campaign. The existing
vmagent hourly aggregation is not a substitute for these raw samples.

`objstore_monitoring` accepts:

| Field | Default |
|---|---|
| `enabled` | `false` |
| `alertmanager_target` | `monitoring-kube-prometheus-alertmanager.monitoring.svc:9093` |
| `stale_scan_seconds` | `86400` |
| `initial_scan_grace` | `24h` |
| `saturation_ratio` | `0.8` |
| `campaign_targets` | `[]` (`list(string)`, private IP `host:port` endpoints) |
| `campaign_run_id` | `""` (string; required when targets are configured) |

Terraform appends the following jobs to the existing `prometheus.serverFiles`
`["prometheus.yml"].scrape_configs`, with 15s scrape and 10s timeout:

| Job | Pod container / named port | Expected targets per tenant |
|---|---|---|
| `objstore-tierer` | `tierer-server` / `tierer-metrics` (8081) | 1 |
| `objstore-updater` | `cwm-minio-tierer-access-updater` / `updater-metrics` (8922) | Sum of pool `servers` (omitted = 1) |
| `objstore-vector` | `cwm-iac-minio-log-metrics` / `vector-metrics` (9598) | Same as updater |
| `objstore-redis` | `redis-exporter` / `redis-metrics` (9121) | 1 |
| `objstore-campaign` (optional static job) | Operator-private campaign HTTP monitor, normally port 9910 | One per configured `campaign_targets` entry |

Discovery is restricted to `minio-tenant-<name>` and an exact container/port pair,
so multiple containers/ports cannot produce repeated per-pod scrapes. Init and
terminal pods are filtered. Labels include `cluster`, `tenant`, `namespace`,
`pod`, plus Prometheus `job`/`instance`. Existing audit collection selects only
`audit-metrics`; existing node/bucket/resource scrapes select only `minio:9000`.
These changes require rollout of the new sidecar port declarations alongside the
metrics configuration. No 8921 scrape is generated.

### Continuous campaign monitor integration

The root module must forward **these exact fields** inside `objstore_monitoring`:

```hcl
objstore_monitoring = {
  enabled          = true
  campaign_targets = ["10.20.30.40:9910"] # Replace with the operator's private monitor address.
  campaign_run_id  = "campaign-test"     # Must match the monitor's manifest run_id.
}
```

Both are optional, with defaults `[]` and `""`. No campaign job or campaign rules
are generated without targets, or when monitoring is disabled. When targets are
configured, `campaign_run_id` must match the actual manifest contract: 6–40
lowercase letters/digits/hyphens, starting with a letter and containing at least
one nonempty hyphen-separated suffix. Duplicate target strings are rejected.

Destinations are explicit **RFC1918 IPv4 literals** or bracketed **ULA IPv6
literals** (for example `[fd12:3456::40]:9910`), with ports 1–65535. URLs, paths,
DNS names, public addresses, loopback, unspecified and link-local destinations
are rejected. DNS cannot establish a reproducible private-destination guarantee.
IPv6 validation parses and checks membership in **`fc00::/7`** (first hextet
`fc00`–`fdff`); short hextets `fd::1` and `fc::1` are **not** ULA and are rejected.
Bind the read-only campaign monitor to its specific operator-private interface,
and allow the tenant Prometheus to reach that interface through the operator's
private routing/firewall. This configuration creates no public ingress and does
not change cluster-wide network policy.

Terraform appends `objstore-campaign` to
`prometheus.serverFiles["prometheus.yml"].scrape_configs`: static targets,
HTTP `/metrics`, 15s scrape interval, 10s timeout, **redirects disabled** and
`honor_labels=false`. Scrape labels are `cluster`, `tenant`, `run_id` and the
normal `instance=<host:port>`; run identity is supplied here, not by the producer.
Only the actual `monitor.py`/`report.py` metric families and their bounded
dimensions are retained. Unknown metric names and object/version/URL/credential
labels are dropped, and a 100000-sample ceiling fails an oversized scrape rather
than accepting unbounded series. The producer additionally bounds its stage,
operation, size, error, status, cohort, state, gate and bound values. Multiple
endpoints under one run must describe that same run; select one endpoint in
Grafana to avoid summing repeated aggregate snapshots.

## Evaluated alerts and dashboards

Rules are rendered from `tfmodules/cwm_minio_tenant/objstore-alerts.yaml.tftpl`
into **`prometheus.serverFiles["alerting_rules.yml"]`**. The bundled Prometheus
chart mounts this file at `/etc/config/alerting_rules.yml` and references it from
`rule_files`. Evaluation is 15s. The profile sets
`prometheus.server.alertmanagers[0].static_configs[0].targets` to the existing
Alertmanager service above; alerts use `severity=warning`, `cluster` and `tenant`
and flow through its existing routing. This does not create inert PrometheusRule
objects or a new notification receiver. Actual network delivery/receiver behavior
must be checked after a separately authorized deployment.

Alerts cover down targets, missing/partially missing fleets, missing updater Go
metrics, stale completed scans, an initial scan exceeding its grace period,
ingestion failures, active updater status-code risk overrides, exhausted daily
budgets, queue pressure, Redis connection/memory/eviction problems, and Vector
disk-buffer/delivery errors. No-success timestamp **0** uses the initial grace
instead of being treated as Unix-epoch staleness. The initial grace restarts when
the condition clears, including a process/scrape outage. Tune both scan thresholds
to the measured full traversal time.

Configured campaign monitors also get evaluated `ObjstoreCampaignTargetDown`,
`ObjstoreCampaignTargetMissing` and `ObjstoreCampaignMonitorStale` alerts. Each
has a 2m pending period. Freshness means the monitor's last successful snapshot
is over **120s** old or its refresh gauge is absent while the scrape is up; it
does not mean every cohort has had a recent object observation. Run the monitor
with its normal 5s refresh interval (or comfortably below 120s).

These alerts arm only after an observed
`cwm_objstore_loadtest_stage_status{status="running"}=1`. Derived recording
rules remember the latest per-stage flags and successful refresh timestamps for
up to **24h**, so a failed scrape does not erase known active-run evidence.
For redundant monitors, a newer idle/completed snapshot overrides an unavailable
monitor's **historical** running flag. Current activity is also recorded per
instance while its scrape is up. A currently running target with missing or stale
refresh telemetry remains eligible for freshness alerts, even when an idle peer
has a current or retained timestamp. A currently idle target does not inherit a
peer's freshness alert. When current activity is absent, its retained activity
requires the run-level, snapshot-ordered gate; newer completion evidence still
disarms stale historical flags. Current evidence from an incomplete/stale active
target is also retained in the run gate rather than interpreted as inactivity.
Never-started runs and runs without retained active evidence do not alert; an
outage beyond the 24h evidence window needs independent operator supervision.
Clear targets when retiring a monitor, and change `campaign_run_id` for each new
run. No `run_active` metric is assumed to exist in the producer.

Validated in disposable containers with Vector **0.51.1**:
`vector_buffer_byte_size`, `vector_buffer_max_byte_size` (5368709120 for this
config), `vector_http_client_errors_total` during connection retries and
`vector_component_errors_total` during invalid audit JSON. The buffer/error
series have `component_id`, with the disk queue identified as `access_updater`.
HTTP retries do **not** necessarily increment `component_errors_total`, so both
error paths are covered. Redis exporter **v1.80.1** was checked against Redis for
`redis_up`, `redis_memory_used_bytes`, `redis_memory_max_bytes`, and
`redis_evicted_keys_total`. An unlimited maxmemory value does not fire the memory
ratio alert.

`objstore_monitoring.enabled` also maps to `apps/grafana-dashboards` →
`minio.objstoreMonitoring`, enabling **Objstore Load Test Overview** and
**Tiering Pipeline**. A tenant-specific datasource UID points to the existing
tenant Prometheus URL, avoiding accidental selection of another tenant. Existing
Grafana/Loki services are reused. New ConfigMap/UID names and **every ConfigMap
data filename** include a stable hash of the tenant namespace:
`objstore-datasource-<hash>.yaml`, `objstore-load-test-overview-<hash>.json`, and
`objstore-tiering-pipeline-<hash>.json`. Dashboard titles append
` - <tenant namespace>`. These remain distinct even with shared provisioning
directories, `sidecar.enableUniqueFilenames=false`, and a shared Grafana folder.

Service panels use the real `cwm_minio_tierer_*` and
`cwm_minio_tierer_updater_*` families. State observations are **not unique
inventory**; accepted marker/restore requests are **not completed transitions or
restores**; cursor age is **not total traversal duration**. UTC budget gauges are
last-observed use, not a continuously refreshed midnight-reset value.

Campaign panels have their own row and use the concrete contract from
`cwm_minio_api/load_tests/campaign/{monitor,report}.py`, scoped by cluster, tenant,
**run_id and one campaign endpoint**:

| Panel | Actual metric / semantics |
|---|---|
| Request rate | `cwm_objstore_loadtest_requests_total`; achieved closed-loop attempts/s by stage/operation; excludes `.expected-negative` probes |
| Successful verified GET throughput | `cwm_objstore_loadtest_response_bytes_total{operation="get_object"}`; bytes/s after full-body length, checksum and version validation, not PUT upload bytes or wire traffic |
| Observed errors (cumulative) | Current sum of `cwm_objstore_loadtest_errors_total` by stage, excluding expected-negative probes; visible from the first positive sample, with zero only when request evidence exists and no error series exists |
| Error rate | Observed **fixed 5m** ratio from `cwm_objstore_loadtest:stage_error_ratio5m`; stable per-stage error totals are recorded before `rate` so the first increment of each sparse error label set is included |
| Error-rate history | `0`: warming/incomplete 5m; `1`: idle observed window; `2`: ready observed window; no result: history unavailable. These are availability states, not health/success flags |
| p95/p99 full-body GET latency | `cwm_objstore_loadtest_request_duration_seconds_bucket{operation="get_object"}` and `_count`; includes failed attempts, finite buckets through 60s; absent or idle histograms give no estimate |
| Stage status | `cwm_objstore_loadtest_stage_status{stage,status}`; one-hot passed/failed/aborted/inconclusive/running gauges |
| Cohort state | `cwm_objstore_loadtest_cohort_objects{cohort,state}`; latest current-seed-version observations, including missing/unknown/invalid/local/cold/restoring/restored |
| Last observation age | `cwm_objstore_loadtest_last_observation_timestamp_seconds{cohort}`; age of the **newest** valid metadata observation per cohort, not the oldest object; zero timestamps omitted |
| Lifecycle completed objects | `cwm_objstore_loadtest_lifecycle_completed_objects{cohort,gate}`; gauge of current versions with passed gate proofs; not a cumulative event counter |
| Restore expiry bounds | `cwm_objstore_loadtest_restore_expiry_timestamp_seconds{cohort,bound}` (`min` or `max`); known deadline bounds, not proof of re-tiering; zero omitted; seconds converted to milliseconds for Grafana date formatting |

There is **no lifecycle latency histogram** in this producer. The panels do not
invent transition/restore/expiry latency estimates from timestamps or completion
counts. Empty campaign panels do not make the service panels unusable.

The unchanged producer creates an `errors_total{stage,operation,size,error}`
series only on its first error, potentially starting above zero. Applying
`rate()` to those individual series loses their initial increments. The campaign
rule group therefore records `cwm_objstore_loadtest:stage_requests_total` and
`:stage_errors_total`, grouped by job/cluster/tenant/run/instance/stage. Error
totals are initialized to zero **only while request evidence is present**. New
error-label combinations then increment the already-observed stage total.

`:stage_error_rate_window_ready` requires a known sample at the five-minute
boundary and all 20 evaluations of both totals in the 5m window (the rule group
evaluates every 15s). `:stage_error_ratio5m` additionally requires observed request
increments. Warming, missing/gapped history and idle windows produce **no error
ratio**, not a false zero. These are IaC recording rules, not additional producer
metrics. If their evaluation interval changes, the window-coverage check must be
updated with it.

A first snapshot that is already positive has unknown pre-scrape error timing.
The cumulative count is shown immediately; those earlier errors cannot be
assigned to a rate window without earlier observations. After a complete later
window, its zero ratio can legitimately coexist with positive cumulative errors:
it means no new errors were observed in that interval, **not** a failure-free run.
The cumulative panel remains visible when a failure stops traffic. No producer
change is needed for these corrections.

## Reproducible offline rendering and tests

From the **cwm-iac repository root**:

```bash
uv sync
uv run python -m tests.render_objstore_profile --output /tmp/opencode/objstore-render
uv run python -m tests.render_objstore_profile --defaults --output /tmp/opencode/objstore-defaults
helm template test apps/minio-tenant -f /tmp/opencode/objstore-render/minio-tenant.yaml
helm template test apps/minio-tenant-metrics -f /tmp/opencode/objstore-render/minio-tenant-metrics.yaml
helm template test apps/grafana-dashboards -f /tmp/opencode/objstore-render/grafana-dashboards.yaml
uv run pytest tests/test_objstore_monitoring.py tests/test_objstore_review.py tests/test_objstore_campaign.py tests/test_objstore_monitoring_review.py tests/test_objstore_exporters.py tests/minio_log_metrics/test_vector_contract.py
uv run pytest
```

For the remote Docker host in this development environment, select the host
explicitly (ordinary local Docker needs neither override):

```bash
TEST_DOCKER_HOST=192.168.50.210 uv run pytest tests/test_objstore_monitoring.py tests/test_objstore_review.py tests/test_objstore_campaign.py tests/test_objstore_monitoring_review.py tests/test_objstore_exporters.py tests/minio_log_metrics/test_vector_contract.py
TEST_DOCKER_HOST=192.168.50.210 E2E_DOCKER_HOST_ADDR=192.168.50.210 uv run pytest
```

The renderer evaluates the **actual provider-free Terraform locals** with
synthetic tenant `test`, cluster `test-cluster`, and pools of 2+1 servers. It emits
both values and rendered YAML/JSON. The enabled example includes the four pipeline
jobs plus the private campaign job (**1+3+3+1+1 = 9 targets**); replace its synthetic
`10.20.30.40:9910` and `campaign-test` before integration. The real `metrics_app.tf` additionally merges existing
MinIO/API/audit jobs and their existing credential handling. It never reads Vault
or cluster state and does not emit credential values.

Tests run the bundled chart, Prometheus v3.5.0 `promtool` config/rule checks and
time-series rule cases, Vector's real VRL tests/config validation, and disposable
Vector/Redis/exporter containers. Scanner image regressions additionally run the
selected registry binary with rendered policy settings and external networking
disabled: config acceptance is distinguished from the expected unavailable-Redis
startup failure. This verifies image/config compatibility without a live MinIO or
Redis service. The legacy image-value fixture is local to this repository.
`TEST_DOCKER_HOST` defaults to **`127.0.0.1`** and overrides the reachable host for
published-port runtime checks. Endpoint default/override regressions need no
containers. Containers are cleaned up.
Successful offline tests establish render/config behavior, **not live scrapes**.

For a root that calls the module, `terraform init -backend=false` followed by
`terraform validate` checks the full module without planning/applying or fetching
secrets. Existing Kubernetes provider resource deprecations may be reported.
Validation is not a cloud plan. On a later authorized rollout, expect Deployment
pod replacement and Prometheus config/PVC-size changes, with resource addresses
and Redis PVC identity retained. Roll back config/images through the existing
IaC workflow; preserve compatible Redis persistence files and retained monitoring
data rather than deleting PVCs.
