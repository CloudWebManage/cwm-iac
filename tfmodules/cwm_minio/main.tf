terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}

variable "force_reinstall_counters" {
  type = map(number)
}

variable "data_path" {
  type = string
}

variable "tools" {
  type = map(string)
}

variable "kubeconfig_path" {
  type = string
}
