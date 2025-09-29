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
    role          = string  # bastion - the bastion node, used for SSH access to the cluster
                            # controlplane1 - the first control plane node
                            # controlplane - secondary control plane nodes
                            # worker - worker nodes, used for running workloads
                            # standalone - a standalone server, not part of the kubernetes cluster
    billing_cycle = optional(string)
    cpu_cores     = number
    cpu_type      = string
    daily_backup  = optional(bool)
    disk_sizes_gb = list(number)
    managed       = optional(bool)
    monthly_traffic_package = optional(string)
    ram_mb        = number
    kamatera_server_name = optional(string)  # Optional override for the Kamatera server name
    ingress       = optional(bool)  # Whether this server should be added to the ingress DNS records
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

variable "data_path" {
  type = string
}

variable "ingress_dns_zone_domain" {
  type = string
}

variable "ingress_dns_zone_id" {
  type = string
}
