terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
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

variable "with_cloudnative_pg" {
  type    = bool
  default = true
}

variable "versions" {
  type = any
  default = {}
}
