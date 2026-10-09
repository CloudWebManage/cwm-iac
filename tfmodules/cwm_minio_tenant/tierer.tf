# Pure configuration locals, also evaluated by the offline render tests.
locals {
  tiererAccessRetentionHours = max(tonumber(var.tierer_config.low_hours), tonumber(var.tierer_config.high_hours)) + 5
  tierer = merge({
    mode                      = "apply"
    apply                     = "true"
    high_include_current      = "true"
    restore_days              = "1"
    coverage_enabled          = "false"
    coverage_template         = ""
    coverage_value            = ""
    daily_transition_attempts = ""
    daily_transition_bytes    = ""
    daily_restore_attempts    = ""
    daily_restore_bytes       = ""
    exclude_buckets           = ""
    exclude_bucket_prefixes   = ""
    chunk_size                = tostring(floor(10000 / (tonumber(var.tierer_config.low_hours) + tonumber(var.tierer_config.high_hours))))
    completion_delay          = "5m"
    retry_delay               = "30s"
    probes_enabled            = "true"
    }, { for k, v in var.tierer_config : k => v if !startswith(k, "updater_") }, {
    access_retention_hours = local.tiererAccessRetentionHours
    access_retention       = "${local.tiererAccessRetentionHours}h"
    resources              = var.tierer_resources
  })
  updater = {
    UPDATER_MAX_BODY_BYTES   = lookup(var.tierer_config, "updater_max_body_bytes", "1073741824")
    UPDATER_MAX_RECORDS      = lookup(var.tierer_config, "updater_max_records", "1000000")
    UPDATER_QUEUE_SIZE       = lookup(var.tierer_config, "updater_queue_size", "128")
    UPDATER_BATCH_MAX_EVENTS = lookup(var.tierer_config, "updater_batch_max_events", "1000000")
    UPDATER_BATCH_MAX_KEYS   = lookup(var.tierer_config, "updater_batch_max_keys", "1000000")
    UPDATER_BATCH_MAX_WAIT   = lookup(var.tierer_config, "updater_batch_max_wait", "50ms")
  }
  # Inline Argo CD Helm values override config value files. Only an explicitly
  # selected shared image may override a caller's existing scanner selection.
  tierer_values = merge({
    tierer      = local.tierer
    tiererRedis = var.tierer_redis_config
    }, var.minio_tierer_image == null ? {} : {
    cwmMinioTierer = { tierer = { image = var.minio_tierer_image } }
  })
  tierer_sidecars = {
    volumes = [{ name = "host-var-lab-vector", hostPath = { path = "/var/lib/vector/", type = "DirectoryOrCreate" } }]
    containers = [
      {
        name         = "cwm-iac-minio-log-metrics"
        image        = var.log_metrics_sidecar_image
        resources    = var.vector_resources
        volumeMounts = [{ name = "host-var-lab-vector", mountPath = "/var/lib/vector/" }]
        ports        = concat([{ name = "audit-metrics", containerPort = 8799 }], var.objstore_monitoring.enabled ? [{ name = "vector-metrics", containerPort = 9598 }] : [])
        env = concat(
          [{ name = "CWM_ACCESS_SUCCESS_ONLY", value = tostring(var.vector_access_config.success_only) }],
          var.vector_access_config.exclude_tierer_identity ? [{
            name = "CWM_TIERER_ACCESS_KEY"
            valueFrom = { secretKeyRef = {
              name     = var.vector_access_config.tierer_identity_secret_name
              key      = var.vector_access_config.tierer_identity_secret_key
              optional = true
            } }
          }] : []
        )
      },
      {
        name      = "cwm-minio-tierer-access-updater"
        image     = coalesce(var.minio_tierer_image, "ghcr.io/cloudwebmanage/cwm-minio-tierer:aa0cbe581d39be5f88c12c57f3d6d9075beea454")
        command   = ["/usr/local/bin/redis-updater"]
        resources = var.updater_resources
        ports     = var.objstore_monitoring.enabled ? [{ name = "updater-metrics", containerPort = 8922 }] : []
        env = concat([
          { name = "INSTANCE_ID", value = var.name },
          { name = "ACCESS_RETENTION", value = local.tierer.access_retention },
          { name = "UPDATER_LISTEN_ADDR", value = "127.0.0.1:8921" },
          { name = "REDIS_ADDR", value = "tierer-redis:6379" }
          ], [for k, v in local.updater : { name = k, value = v }],
          var.objstore_monitoring.enabled ? [{ name = "UPDATER_METRICS_LISTEN_ADDR", value = "0.0.0.0:8922" }] : []
        )
      }
    ]
  }
}
