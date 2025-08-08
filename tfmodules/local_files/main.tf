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

variable "bootstrap_all" {
  type = bool
  default = true
}

variable "commands" {
  type = map(object({
    command = string
    file_path = string
    bootstrap = optional(bool, false)
  }))
}

variable "terraform_remote_state" {
  type = object({
    backend = string
    config  = map(string)
    output  = string
  })
  default = {
    backend = ""
    config  = {}
    output  = ""
  }
}

data "external" "fetch" {
  for_each = {for key, command in var.commands: key => command if var.bootstrap_all || command.bootstrap}
  program = [
    "bash", "-c",
    <<-EOT
      set -euo pipefail
      (
        ${each.value.command}
      ) | jq -Rs '{content: .}'
    EOT
  ]
}

data "terraform_remote_state" "content" {
  count = (var.bootstrap_all || alltrue([for key, command in var.commands : command.bootstrap])) ? 0 : 1
  backend = var.terraform_remote_state.backend
  config = var.terraform_remote_state.config
}

resource "local_file" "content" {
  for_each = {for key, command in var.commands: key => command}
  filename = each.value.file_path
  content = (
    var.bootstrap_all || each.value.bootstrap
  ) ? (
    data.external.fetch[each.key].result.content
  ) : (
    lookup(lookup(data.terraform_remote_state.content[0].outputs, var.terraform_remote_state.output, {}), each.key, "")
  )
}

output "content" {
  value = {for key, resource in local_file.content : key => resource.content}
}
