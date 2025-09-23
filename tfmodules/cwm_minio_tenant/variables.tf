variable "name" {
  type = string
}

variable "app_extra_sources" {
  type = any
  default = []
}

variable "app_helm_overrides" {
  type = any
  default = {}
}

variable "ingress_star_domain" {
  type = string
}

variable "minio_image_tag" {
  type = string
  default = "RELEASE.2025-07-23T15-54-02Z"
}

variable "pools" {
  type = map(any)
}

variable "tools" {
  type = any
}

variable "vault_mount" {
  type = string
}

variable "vault_path" {
  type = string
}

variable "initialize" {
  type = bool
}

variable "metrics" {
  type = bool
}

variable "versions" {
  type = any
}

variable "argocdConfigSource" {
  type = any
  default = {}
}
