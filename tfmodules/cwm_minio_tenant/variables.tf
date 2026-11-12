variable "name" {
  type = string
}

variable "ingress_star_domain" {
  type = string
}

variable "minio_image_tag" {
  type    = string
  default = "RELEASE.2025-07-23T15-54-02Z"
}

variable "pools" {
  type = map(any)
}

variable "tools" {
  type = any
}

variable "vault_mount" {
  type = string
}

variable "vault_path" {
  type = string
}

variable "initialize" {
  type = bool
}

variable "metrics" {
  type = bool
}

variable "versions" {
  type = any
}

variable "argocdConfigSource" {
  type    = any
  default = {}
}

variable "erasure_code_standard" {
  type = string
}

variable "erasure_code_reduced" {
  type = string
}

variable "minio_domain" {
  type = string
}

variable "zone_id" {
  type = string
}

variable "vmagentRemoteWriteConfig" {
  type    = any
  default = {}
}

variable "cluster_name" {
  type = string
}

variable "console_ingress_whitelist_source_range" {
  type    = string
  default = ""
}

variable "metrics_app_target_revision" {
  type    = string
  default = "main"
}

variable "log_metrics_sidecar_image" {
  type    = string
  default = "ghcr.io/cloudwebmanage/cwm-iac-minio-log-metrics:c6a5bfff6872857b257d93e8b83d9dd719eea5f1"
}

variable "vmagent_cluster_label" {
  type    = string
  default = ""
}

variable "etcd_use_systemlogging_role" {
  type    = bool
  default = false
}

variable "node_local_enabled" {
  type    = bool
  default = false
}

variable "argocd_autosync" {
  type    = bool
  default = false
}

variable "kubeconfig_path" {
  type = string
}

variable "minio_tierer_image" {
  type        = string
  default     = null
  description = "Optional explicit shared scanner AND redis-updater image. Null preserves the scanner config value-file selection and legacy updater fallback. Monitoring requires an explicit new build supporting UPDATER_METRICS_LISTEN_ADDR."
  validation {
    condition     = var.minio_tierer_image == null ? true : trimspace(var.minio_tierer_image) != ""
    error_message = "minio_tierer_image must be null (preserve legacy image selection) or a nonempty explicit image."
  }
}

variable "tierer_config" {
  type        = map(string)
  default     = {}
  description = "Flat scanner/updater settings; numbers and booleans are converted to strings. See docs/objstore-load-test-monitoring.md for the exact contract."

  validation {
    condition = alltrue([for k in keys(var.tierer_config) : contains([
      "low_hours", "low_threshold", "high_hours", "high_threshold", "mode", "apply",
      "high_include_current", "restore_days", "coverage_enabled", "coverage_template", "coverage_value",
      "daily_transition_attempts", "daily_transition_bytes", "daily_restore_attempts", "daily_restore_bytes",
      "exclude_buckets", "exclude_bucket_prefixes", "chunk_size", "completion_delay", "retry_delay", "probes_enabled",
      "updater_max_body_bytes", "updater_max_records", "updater_queue_size", "updater_batch_max_events",
      "updater_batch_max_keys", "updater_batch_max_wait"
    ], k)])
    error_message = "Unknown tierer_config key; consult the documented flat configuration contract."
  }
  validation {
    condition     = alltrue([for k in ["low_hours", "high_hours", "low_threshold", "high_threshold"] : can(regex("^[0-9]+$", var.tierer_config[k]))])
    error_message = "tierer_config requires integer low_hours, high_hours, low_threshold and high_threshold (as before)."
  }
  validation {
    condition = alltrue([for k in ["daily_transition_attempts", "daily_transition_bytes", "daily_restore_attempts", "daily_restore_bytes"] :
      lookup(var.tierer_config, k, "") == "" ? true : try(can(regex("^[1-9][0-9]*$", var.tierer_config[k])) && tonumber(var.tierer_config[k]) <= 9223372036854775807, false)
    ])
    error_message = "Daily limits must be empty (legacy unlimited) or positive int64 integers."
  }
  validation {
    condition = contains(["audit", "apply"], lookup(var.tierer_config, "mode", "apply")) && alltrue([
      for k in ["apply", "high_include_current", "coverage_enabled", "probes_enabled"] : contains(["true", "false"], lookup(var.tierer_config, k, "true"))
    ])
    error_message = "mode must be audit/apply and boolean settings must be true/false."
  }
  validation {
    condition = try(
      tonumber(var.tierer_config.low_hours) > 0 && tonumber(var.tierer_config.high_hours) > 0 &&
      tonumber(lookup(var.tierer_config, "chunk_size", floor(10000 / (tonumber(var.tierer_config.low_hours) + tonumber(var.tierer_config.high_hours))))) >= 1 &&
      tonumber(lookup(var.tierer_config, "chunk_size", floor(10000 / (tonumber(var.tierer_config.low_hours) + tonumber(var.tierer_config.high_hours))))) * (tonumber(var.tierer_config.low_hours) + tonumber(var.tierer_config.high_hours)) <= 10000,
      false
    )
    error_message = "Positive windows/chunk_size must satisfy chunk_size * (low_hours + high_hours) <= 10000."
  }
  validation {
    condition = alltrue([for k in ["updater_max_records", "updater_queue_size", "updater_batch_max_events", "updater_batch_max_keys"] :
      try(can(regex("^[1-9][0-9]*$", lookup(var.tierer_config, k, "1"))) && tonumber(lookup(var.tierer_config, k, "1")) <= 1000000, false)
      ]) && try(
      can(regex("^[1-9][0-9]*$", lookup(var.tierer_config, "updater_max_body_bytes", "1073741824"))) && tonumber(lookup(var.tierer_config, "updater_max_body_bytes", "1073741824")) <= 1073741824 &&
      tonumber(lookup(var.tierer_config, "updater_batch_max_events", "1000000")) >= tonumber(lookup(var.tierer_config, "updater_max_records", "1000000")) &&
      tonumber(lookup(var.tierer_config, "updater_batch_max_keys", "1000000")) >= tonumber(lookup(var.tierer_config, "updater_max_records", "1000000")), false
    )
    error_message = "Updater counts must be positive and <= 1000000, body bytes <= 1073741824, and one request must fit both batch limits."
  }
  validation {
    condition = alltrue([for k in ["completion_delay", "retry_delay", "updater_batch_max_wait"] :
      can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|µs|ms|s|m|h))+$", lookup(var.tierer_config, k, "1s"))) && can(regex("[1-9]", lookup(var.tierer_config, k, "1s")))
    ])
    error_message = "Delays must be positive Go duration strings, e.g. 50ms, 30s or 5m."
  }
}

variable "tierer_resources" {
  type    = object({ requests = optional(map(string), {}), limits = optional(map(string), {}) })
  default = {}
}

variable "updater_resources" {
  type    = object({ requests = optional(map(string), {}), limits = optional(map(string), {}) })
  default = {}
}

variable "vector_resources" {
  type    = object({ requests = optional(map(string), {}), limits = optional(map(string), {}) })
  default = {}
}

variable "tierer_redis_config" {
  type = object({
    appendonly         = optional(bool, false)
    appendfsync        = optional(string, "everysec")
    maxmemory_policy   = optional(string, "noeviction")
    maxmemory          = optional(string, "0")
    resources          = optional(object({ requests = optional(map(string), {}), limits = optional(map(string), {}) }), {})
    exporter_enabled   = optional(bool, false)
    exporter_image     = optional(string, "oliver006/redis_exporter:v1.80.1")
    exporter_resources = optional(object({ requests = optional(map(string), {}), limits = optional(map(string), {}) }), {})
  })
  default = {}
  validation {
    condition = contains(["always", "everysec", "no"], var.tierer_redis_config.appendfsync) && contains([
      "noeviction", "allkeys-lru", "allkeys-lfu", "allkeys-random", "volatile-lru", "volatile-lfu", "volatile-random", "volatile-ttl"
    ], var.tierer_redis_config.maxmemory_policy) && can(regex("^[0-9]+([kKmMgG][bB]?)?$", var.tierer_redis_config.maxmemory))
    error_message = "Redis requires a valid appendfsync, maxmemory policy and non-negative Redis memory size."
  }
}

variable "vector_access_config" {
  type = object({
    success_only                = optional(bool, false)
    exclude_tierer_identity     = optional(bool, false)
    tierer_identity_secret_name = optional(string, "cwm-minio-api-tenant-creds")
    tierer_identity_secret_key  = optional(string, "accesskey")
  })
  default     = {}
  description = "Only affects access records sent to Redis; audit metrics retain their existing attribution. Identity is read through an optional Secret reference."
}

variable "metrics_retention" {
  type    = string
  default = "2d"
  validation {
    condition     = can(regex("^[1-9][0-9]*[hdw]$", var.metrics_retention))
    error_message = "metrics_retention must be a positive integer followed by h, d or w."
  }
}

variable "metrics_storage_size" {
  type    = string
  default = "50Gi"
}

variable "objstore_monitoring" {
  type = object({
    enabled             = optional(bool, false)
    alertmanager_target = optional(string, "monitoring-kube-prometheus-alertmanager.monitoring.svc:9093")
    stale_scan_seconds  = optional(number, 86400)
    initial_scan_grace  = optional(string, "24h")
    saturation_ratio    = optional(number, 0.8)
    campaign_targets    = optional(list(string), [])
    campaign_run_id     = optional(string, "")
  })
  default = {}
  validation {
    condition = !var.objstore_monitoring.enabled || (
      var.metrics && var.tierer_redis_config.exporter_enabled &&
      (var.minio_tierer_image == null ? false : !contains([
        "ghcr.io/cloudwebmanage/cwm-minio-tierer:aa0cbe581d39be5f88c12c57f3d6d9075beea454",
        "ghcr.io/cloudwebmanage/cwm-minio-tierer:34ef901cf197b7479e25714184a68d84ca0d0943"
      ], var.minio_tierer_image)) &&
      var.log_metrics_sidecar_image != "ghcr.io/cloudwebmanage/cwm-iac-minio-log-metrics:c6a5bfff6872857b257d93e8b83d9dd719eea5f1"
    )
    error_message = "Objstore monitoring requires metrics=true, Redis exporter enabled, and explicitly selected newly built tierer/updater AND Vector images."
  }
  validation {
    condition     = var.objstore_monitoring.stale_scan_seconds > 0 && var.objstore_monitoring.saturation_ratio > 0 && var.objstore_monitoring.saturation_ratio < 1 && can(regex("^[1-9][0-9]*[mhd]$", var.objstore_monitoring.initial_scan_grace)) && var.objstore_monitoring.alertmanager_target != ""
    error_message = "Monitoring requires a positive stale-scan threshold, initial grace in m/h/d, saturation ratio between 0 and 1, and Alertmanager target."
  }
  validation {
    condition = length(var.objstore_monitoring.campaign_targets) == 0 || (
      length(var.objstore_monitoring.campaign_run_id) >= 6 && length(var.objstore_monitoring.campaign_run_id) <= 40 &&
      can(regex("^[a-z][a-z0-9]*(?:-[a-z0-9]+)+$", var.objstore_monitoring.campaign_run_id))
    )
    error_message = "Configured campaign targets require a nonempty campaign_run_id matching the campaign manifest: 6..40 lowercase alphanumeric/hyphen characters, with at least one hyphen-separated suffix."
  }
  validation {
    condition     = length(distinct(var.objstore_monitoring.campaign_targets)) == length(var.objstore_monitoring.campaign_targets)
    error_message = "campaign_targets must not contain duplicate endpoints."
  }
  validation {
    # Explicit IPs prevent DNS resolution or redirects from escaping the intended
    # operator-private destination. Exclude loopback/link-local/unspecified hosts.
    condition = alltrue([for target in var.objstore_monitoring.campaign_targets : try(
      (
        (can(regex("^(10\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|192\\.168\\.)[0-9.]+:[1-9][0-9]{0,4}$", target)) &&
        try(cidrhost("${split(":", target)[0]}/32", 0) == split(":", target)[0], false)) ||
        (can(regex("^\\[f[cd][0-9a-f:]+\\]:[1-9][0-9]{0,4}$", lower(target))) &&
        try(cidrhost("${regex("^\\[([^]]+)\\]:", target)[0]}/7", 0) == "fc00::", false))
      ) && tonumber(regex(":([0-9]+)$", target)[0]) <= 65535,
      false
    )])
    error_message = "campaign_targets must be explicit RFC1918 IPv4:port or [ULA IPv6]:port endpoints on the operator private network (ports 1..65535); DNS names, URLs, public, loopback and link-local addresses are not accepted."
  }
}

variable "low_tier_s3" {
  type    = map(any)
  default = {}
}
