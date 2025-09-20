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
  type = any
  default = {}
}

variable "geolocation_set_identifier" {
  type = string
  default = ""
}

variable "is_primary" {
  type = bool
  default = false
}

variable "allowed_primary_cluster_name" {
  type = string
  default = ""
}

variable "secondaries" {
  type = map(object({
    cluster_name = string
  }))
  default = {}
}
