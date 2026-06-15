variable "name_prefix" {
  type = string
}

variable "zone_id" {
  type = string
}

variable "zone_domain" {
  type = string
}

variable "edge_server_public_ips" {
  type = list(string)
}

variable "vault_mount" {
  type = string
}

variable "vault_path" {
  type = string
}

variable "tools" {
  type = any
}

variable "kubeconfig_path" {
  type = string
}

variable "data_path" {
  type = string
}

variable "versions" {
  type = any
}

variable "geolocation_routing_policy" {
  type    = any
  default = {}
}

variable "geolocation_routing_policies" {
  type    = any
  default = {}
}

variable "geolocation_set_identifier" {
  type    = string
  default = ""
}

variable "is_primary" {
  type    = bool
  default = false
}

variable "allowed_primary_cluster_name" {
  type    = string
  default = ""
}

variable "secondaries" {
  type = map(object({
    cluster_name = string
  }))
  default = {}
}

variable "argocdConfigSource" {
  type    = any
  default = {}
}

variable "geo_prefix" {
  type    = string
  default = "geo"
}

variable "vmagentRemoteWriteConfig" {
  type    = any
  default = {}
}

variable "cdn_operator_log_level" {
  type    = string
  default = "1"
}

variable "argocd_autosync" {
  type    = bool
  default = false
}

variable "tenant_certs_letsencrypt_email" {
  type = string
}

variable "cache_servers" {
  type = map(object({
    nodeName = string
  }))
  default = {
    cache1 = { nodeName = "cdn1" }
    cache2 = { nodeName = "cdn1" }
    cache3 = { nodeName = "cdn1" }
  }
}

variable "cache_admin_enabled" {
  type    = bool
  default = true
}

variable "cache_admin_port" {
  type    = number
  default = 8081
}

variable "cache_admin_token_secret_name" {
  type    = string
  default = "cwm-cdn-cache-admin"
}

variable "cache_admin_token_secret_key" {
  type    = string
  default = "token"
}

variable "cache_admin_network_policy_enabled" {
  type    = bool
  default = true
}

variable "pop_id" {
  type    = string
  default = ""
}

variable "cdn_policy_enabled" {
  type    = bool
  default = false
}

variable "cdn_trusted_client_ip_enabled" {
  type    = bool
  default = false
}

variable "cdn_trusted_proxy_cidrs" {
  type    = list(string)
  default = []
}

variable "cdn_captcha_egress_enabled" {
  type    = bool
  default = false
}

variable "cdn_structured_logs_enabled" {
  type    = bool
  default = true
}

variable "cdn_platform_logs_enabled" {
  type    = bool
  default = false
}

variable "cdn_pop_health_enabled" {
  type    = bool
  default = true
}

variable "route53_pop_health_dns_automation_enabled" {
  type    = bool
  default = false

  validation {
    condition     = var.route53_pop_health_dns_automation_enabled == false
    error_message = "Automatic Route53 POP health DNS writes are intentionally disabled until a follow-up approved plan enables them."
  }
}

variable "route53_pop_health_dns_dry_run_enabled" {
  type    = bool
  default = false
}
