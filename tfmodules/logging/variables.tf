variable "ingress_star_domain" {
  type        = string
}

variable "versions" {
  type        = any
  default     = {}
}

variable "argocd_autosync" {
  type        = bool
  default     = false
}
