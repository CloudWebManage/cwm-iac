variable "ingress_star_domain" {
  type        = string
}

variable "versions" {
  type        = any
  default     = {}
}

variable "argocd_autosync" {
  type        = bool
  default     = false
}

variable "tools" {
  type = map(string)
}

variable "kubeconfig_path" {
  type = string
}
variable "minio_storage_size" {
  type = string
  default = "999Gi"
}

variable "loki_write_storage_size" {
  type = string
  default = "20Gi"
}

variable "minio_init_image" {
  description = "Original image of a completed logging initialization Job; null uses the chart default for new installations."
  type = string
  default = null
}
