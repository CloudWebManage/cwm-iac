variable "data_path" {
  type = string
}

variable "versions" {
  type = any
  default = {}
}

variable "admin_kubeconfig_path" {
  type = string
}

variable "tools" {
  type = any
  default = {}
}

variable "config" {
  type = any
}

variable "ingress_star_domain" {
  type = string
}

variable "vault_mount" {
  type = string
}

variable "vault_path" {
  type = string
}
