terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [
        aws.route53,
        aws.default,
      ]
    }
  }
}

variable "cluster_name" {
  type = string
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

variable "argocd_autosync" {
  type    = bool
  default = false
}

variable "low_tier_s3_region" {
  type = string
}

variable "create_low_tier_s3" {
  description = "Create the external S3 tier for object-store tenants."
  type        = bool
  default     = true
}
