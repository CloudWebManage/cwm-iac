terraform {
  required_providers {
    kamatera = {
      source = "Kamatera/kamatera"
    }
    random = {
      source  = "hashicorp/random"
    }
    null = {
      source  = "hashicorp/null"
    }
    local = {
      source  = "hashicorp/local"
    }
    external = {
      source  = "hashicorp/external"
    }
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [
        aws.route53
      ]
    }
  }
}

