terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
    external = {
      source = "hashicorp/external"
    }
  }
}

variable "bootstrap" {
  type = bool
  default = true
}

variable "command" {
  type = string
}

variable "file_path" {
  type = string
  default = ""
}

variable "terraform_remote_state" {
  type = object({
    backend = string
    config  = map(string)
    output  = string
    output_subkey = optional(string, "")
  })
  default = {
    backend = ""
    config  = {}
    output  = ""
    output_subkey = ""
  }
}

data "external" "fetch" {
  count = var.bootstrap ? 1 : 0
  program = [
    "bash", "-c",
    <<-EOT
      set -euo pipefail
      (
        ${var.command}
      ) | jq -Rs '{content: .}'
    EOT
  ]
}

data "terraform_remote_state" "content" {
  count = var.bootstrap ? 0 : 1
  backend = var.terraform_remote_state.backend
  config = var.terraform_remote_state.config
}

resource "local_file" "content_bootstrap" {
  filename = var.file_path
  content = var.bootstrap ?
    data.external.fetch[0].result.content :
    (
      var.terraform_remote_state.output_subkey == "" ?
        data.terraform_remote_state.content[0].outputs[var.terraform_remote_state.output] :
        data.terraform_remote_state.content[0].outputs[var.terraform_remote_state.output][var.terraform_remote_state.output_subkey]
    )
}

output "content" {
  value = local_file.content_bootstrap.content
}
