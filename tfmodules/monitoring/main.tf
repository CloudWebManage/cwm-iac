terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    random = {
      source  = "hashicorp/random"
    }
    vault = {
      source  = "hashicorp/vault"
    }
  }
}
