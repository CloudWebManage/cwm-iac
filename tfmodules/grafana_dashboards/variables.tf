variable "tenant_name" {
  type        = string
  default     = "main"
  description = "Name of the MinIO tenant"
}

variable "targetRevision" {
  type        = string
  default     = "main"
  description = "Git revision for cwm-iac repository"
}
