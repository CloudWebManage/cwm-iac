variable "name_prefix" {
  type        = string
}

variable "main_server_datacenter_id" {
  type        = string
  default = "IL"
}

variable "ssh_pubkey" {
  type        = string
}

variable "workers" {
  type = map(object({
    datacenter_id = string
  }))
}

variable "data_path" {
  type = string
}

variable "locust_env_config" {
  type = map(string)
}

variable "cluster_name" {
  type = string
}
