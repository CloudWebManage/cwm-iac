terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    null = {
      source  = "hashicorp/null"
    }
    vault = {
      source  = "hashicorp/vault"
    }
  }
}
