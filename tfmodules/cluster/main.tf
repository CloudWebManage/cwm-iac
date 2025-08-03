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
  }
}

variable "name_prefix" {
  type        = string
}

variable "datacenter_id" {
  type        = string
}

variable "image_id" {
  type        = string
}

variable "default_billing_cycle" {
  type        = string
  default     = "hourly"
}

variable "default_monthly_traffic_package" {
  type        = string
  default     = ""
}

variable "default_daily_backup" {
  type        = bool
  default     = false
}

variable "default_managed" {
  type        = bool
  default     = false
}

variable "ssh_pubkey" {
  type        = string
}

variable "servers" {
  type = map(object({
    role          = string
    billing_cycle = optional(string)
    cpu_cores     = number
    cpu_type      = string
    daily_backup  = optional(bool)
    disk_sizes_gb = list(number)
    managed       = optional(bool)
    monthly_traffic_package = optional(string)
    ram_mb        = number
  }))
}

variable "private_network_name" {
  type = string
}

variable "rke2_version" {
  type = string
}

variable "admin_kubeconfig_path" {
  type = string
}
