terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "name_prefix" {
  type = string
}

variable "zone_id" {
  type = string
}

variable "zone_domain" {
  type = string
}

variable "ingress_servers" {
  type = map(object({
    public_ip   = string
  }))
}

variable "cdn" {
  type = any
}
