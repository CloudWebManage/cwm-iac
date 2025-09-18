terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}

variable "name" {
  type = string
}

variable "namespace" {
  type = string
  default = ""
}

variable "create_namespace" {
  type = bool
  default = true
}

variable "project" {
  type = string
  default = "default"
}

variable "targetRevision" {
  type = string
  default = "main"
}

variable "path" {
  type = string
  default = ""
}

variable "values" {
  type = any
  default = {}
  description = "only relevant if sources is not set"
}

variable "autosync" {
  type = bool
  default = false
  description = "only relevant if sync_policy is not set"
}

variable "sources" {
  type = any
  default = null
  description = "if this is set you define the sources"
}

variable "sync_policy" {
  type = any
  default = null
  description = "if this is set you define the syncPolicy"
}
