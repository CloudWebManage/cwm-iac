terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    random = {
      source  = "hashicorp/random"
    }
  }
}

variable "ingress_star_domain" {
  type = string
}

variable "data_path" {
  type = string
}

variable "tools" {
  type = map(string)
}

variable "minio_tenant_main_app_extra_sources" {
  type = any
  default = []
}

variable "minio_tenant_main_app_helm_overrides" {
  type = any
  default = {}
}

variable "vault_mount" {
  type = string
}

variable "vault_path" {
  type = string
}
