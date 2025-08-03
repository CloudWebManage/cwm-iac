terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
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

variable "kube_version" {
  type = string
}

variable "tools_data_path" {
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
