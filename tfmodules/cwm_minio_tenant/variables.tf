variable "name" {
  type = string
}

variable "ingress_star_domain" {
  type = string
}

variable "minio_image_tag" {
  type = string
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
  type = any
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
  type = any
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
