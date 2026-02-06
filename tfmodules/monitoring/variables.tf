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
