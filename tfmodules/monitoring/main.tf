terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    random = {
      source  = "hashicorp/random"
    }
    vault = {
      source  = "hashicorp/vault"
    }
  }
}

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
