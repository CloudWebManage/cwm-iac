locals {
  objstore_jobs = {
    objstore-tierer  = { container = "tierer-server", port = "tierer-metrics", expected = 1 }
    objstore-updater = { container = "cwm-minio-tierer-access-updater", port = "updater-metrics", expected = sum([for pool in values(var.pools) : lookup(pool, "servers", 1)]) }
    objstore-vector  = { container = "cwm-iac-minio-log-metrics", port = "vector-metrics", expected = sum([for pool in values(var.pools) : lookup(pool, "servers", 1)]) }
    objstore-redis   = { container = "redis-exporter", port = "redis-metrics", expected = 1 }
  }
  objstore_pod_scrape_configs = var.objstore_monitoring.enabled ? [for name, job in local.objstore_jobs : {
    job_name              = name
    scrape_interval       = "15s"
    scrape_timeout        = "10s"
    metrics_path          = "/metrics"
    kubernetes_sd_configs = [{ role = "pod", namespaces = { names = ["minio-tenant-${var.name}"] } }]
    relabel_configs = [
      # Pod discovery emits a target for EACH declared container port. Keep one exact pair.
      { source_labels = ["__meta_kubernetes_pod_container_name", "__meta_kubernetes_pod_container_port_name"], action = "keep", regex = "${job.container};${job.port}" },
      { source_labels = ["__meta_kubernetes_pod_phase"], action = "drop", regex = "Succeeded|Failed" },
      { source_labels = ["__meta_kubernetes_pod_container_init"], action = "drop", regex = "true" },
      { source_labels = ["__meta_kubernetes_pod_name"], target_label = "pod" },
      { source_labels = ["__meta_kubernetes_namespace"], target_label = "namespace" },
      { target_label = "cluster", replacement = var.cluster_name },
      { target_label = "tenant", replacement = var.name }
    ]
  }] : []
  objstore_campaign_scrape_configs = var.objstore_monitoring.enabled && length(var.objstore_monitoring.campaign_targets) > 0 ? [{
    job_name         = "objstore-campaign"
    scheme           = "http"
    metrics_path     = "/metrics"
    scrape_interval  = "15s"
    scrape_timeout   = "10s"
    follow_redirects = false
    honor_labels     = false
    sample_limit     = 100000
    static_configs = [{
      targets = var.objstore_monitoring.campaign_targets
      labels  = { cluster = var.cluster_name, tenant = var.name, run_id = var.objstore_monitoring.campaign_run_id }
    }]
    # Only the bounded monitor.py/report.py contract. No object key, version ID,
    # bucket, URL or credential dimensions are retained from a scrape response.
    metric_relabel_configs = [
      {
        source_labels = ["__name__"]
        action        = "keep"
        regex         = "cwm_objstore_loadtest_(requests_total|response_bytes_total|request_duration_seconds_(bucket|sum|count)|errors_total|admitted_requests_total|admitted_bytes_total|stage_status|cohort_objects|last_observation_timestamp_seconds|lifecycle_completed_objects|lifecycle_last_completion_timestamp_seconds|restore_expiry_timestamp_seconds|renewal_scheduled_timestamp_seconds|monitor_up|monitor_last_refresh_timestamp_seconds)"
      },
      {
        action = "labelkeep"
        regex  = "__name__|job|instance|cluster|tenant|run_id|stage|operation|size|error|le|status|cohort|state|gate|bound"
      }
    ]
  }] : []
  objstore_scrape_configs = concat(local.objstore_pod_scrape_configs, local.objstore_campaign_scrape_configs)
  objstore_metrics_values = {
    prometheus = {
      server = {
        retention        = var.metrics_retention
        persistentVolume = { size = var.metrics_storage_size }
        # rule evaluation and routing run in the tenant Prometheus (not a PrometheusRule CR).
        global = {
          scrape_interval     = var.objstore_monitoring.enabled ? "15s" : "1m"
          evaluation_interval = var.objstore_monitoring.enabled ? "15s" : "1m"
        }
        alertmanagers = var.objstore_monitoring.enabled ? [{ static_configs = [{ targets = [var.objstore_monitoring.alertmanager_target] }] }] : []
      }
      serverFiles = {
        "prometheus.yml" = { scrape_configs = local.objstore_scrape_configs }
        "alerting_rules.yml" = yamldecode(templatefile("${path.module}/objstore-alerts.yaml.tftpl", {
          enabled            = var.objstore_monitoring.enabled
          jobs               = local.objstore_jobs
          cluster            = var.cluster_name
          tenant             = var.name
          stale_scan_seconds = var.objstore_monitoring.stale_scan_seconds
          initial_scan_grace = var.objstore_monitoring.initial_scan_grace
          saturation_ratio   = var.objstore_monitoring.saturation_ratio
          queue_size         = local.updater.UPDATER_QUEUE_SIZE
          campaign_targets   = var.objstore_monitoring.campaign_targets
          campaign_run_id    = var.objstore_monitoring.campaign_run_id
        }))
      }
    }
  }
}
