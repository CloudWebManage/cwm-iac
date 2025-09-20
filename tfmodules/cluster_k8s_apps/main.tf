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

variable "name_prefix" {
  type = string
}

variable "versions" {
  type = map(string)
}

variable "data_path" {
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
    worker-role          = string  # system - used for system / management workloads
                                   # any other value is considered an application workload node, it's used to label/taint the nodes
  }))
}

variable "servers_ssh_command" {
  type = map(string)
}

variable "admin_kubeconfig_path" {
  type = string
}

variable "tools" {
  type = any
}

variable "vault_external_server" {
  type = string
  sensitive = true
}

variable "vault_ca_bundle_b64" {
  type = string
  sensitive = true
}
