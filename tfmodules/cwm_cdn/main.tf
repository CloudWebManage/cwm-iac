terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [
        aws.route53
      ]
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

variable "edge_server_public_ips" {
  type = list(string)
}

variable "vault_mount" {
  type = string
}

variable "vault_path" {
  type = string
}

variable "tools" {
  type = any
}

variable "ingress_dns_zone_domain" {
  type = string
}

variable "kubeconfig_path" {
  type = string
}

variable "data_path" {
  type = string
}

variable "versions" {
  type = any
}
