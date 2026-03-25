variable "vault_mount" {
  type = string
}

variable "vault_path" {
  type = string
}

variable "ingress_star_domain" {
  type = string
}

variable "tools" {
  type = any
}

variable "slack_alerts_webhook_url" {
  type = string
  sensitive = true
}

variable "slack_alerts_watchdog_webhook_url" {
  type = string
  sensitive = true
}

variable "cluster_name" {
  type = string
}

variable "versions" {
  type = any
  default = {}
}

variable "argocd_autosync" {
  type    = bool
  default = false
}

variable "argocdConfigSource" {
  type = any
  default = {}
}

variable "send_nsca_cfg" {
  type = string
  default = ""
}

variable "send_nsca_host" {
  type = string
  default = ""
}

variable "prometheus_nagios_sender_config_yaml" {
  type = string
  default = ""
}

variable "kubeconfig_path" {
  type = string
}