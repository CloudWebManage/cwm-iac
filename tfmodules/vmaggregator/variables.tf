variable "data_path" {
  type = string
}

variable "versions" {
  type = any
  default = {}
}

variable "admin_kubeconfig_path" {
  type = string
}

variable "tools" {
  type = any
  default = {}
}

variable "config" {
  type = any
}
