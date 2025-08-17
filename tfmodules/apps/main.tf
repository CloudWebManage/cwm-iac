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
