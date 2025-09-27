terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    null = {
      source  = "hashicorp/null"
    }
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [
        aws.route53
      ]
    }
  }
}
