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

variable "local_files_terraform_remote_state" {
  type = object({
    backend = string
    config = map(string)
    output = string
  })
}

variable "data_path" {
  type = string
}
