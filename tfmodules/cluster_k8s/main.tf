terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    null = {
      source  = "hashicorp/null"
    }
  }
}

variable "controlplane1_node_name" {
  type = string
}

variable "kubeconfig_path" {
  type = string
}

variable "argocd_version" {
  type = string
}

variable "data_path" {
  type = string
}

variable "ingress_star_domain" {
  type = string
}

variable "certmanager_version" {
  type = string
}

variable "letsencrypt_email" {
  type = string
}

variable "force_reinstall_counters" {
  type = map(number)
}

variable "workers" {
  type = map(object({
    worker-role          = string  # minio - used for running the minio tenants
                                   # cdn - used for running the cdn tenants
                                   # system - used for all other system / management workloads
  }))
}

variable "servers_ssh_command" {
  type = map(string)
}

variable "longhorn_version" {
  type = string
}

variable "tools" {
  type = any
  default = {}
}
