terraform {
  required_version = ">= 1.9.0"
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
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
