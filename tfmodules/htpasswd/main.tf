variable "htpasswd_remote_state_key" {
  type = string
}

variable "data_path_htpasswd_filename" {
  type = string
}

variable "local_files_terraform_remote_state" {
  type = object({
    backend = string
    config = map(string)
    output = string
  })
}

variable "bootstrap" {
  type = bool
}

variable "secrets" {
  type = list(object({
    name  = string
    namespace = string
  }))
}

resource "random_password" "username" {
  length = 8
  special = false
}
resource "random_password" "password" {
  length = 24
  special = false
}

module "local_files_htpasswd" {
  depends_on = [random_password.username, random_password.password]
  source = "git::https://github.com/CloudWebManage/cwm-iac.git//tfmodules/local_files?ref=main"
  # source = "../../../cwm-iac/tfmodules/local_files"
  commands = {
    (var.htpasswd_remote_state_key) : {
      command   = <<-EOT
        htpasswd -bn "${random_password.username.result}" "${random_password.password.result}"
      EOT
      file_path = var.data_path_htpasswd_filename
    }
  }
  terraform_remote_state = var.local_files_terraform_remote_state
  bootstrap_all = var.bootstrap
}

resource "kubernetes_secret" "htpasswd" {
  for_each = {for secret in var.secrets : "${secret.name}-${secret.namespace}" => secret}
  metadata {
    name      = each.value.name
    namespace = each.value.namespace
  }
  type = "Opaque"
  data = {
    auth = module.local_files_htpasswd.content[var.htpasswd_remote_state_key]
  }
}

output "username" {
  value = random_password.username.result
  sensitive = true
}

output "password" {
  value = random_password.password.result
  sensitive = true
}

output "content" {
  value = module.local_files_htpasswd.content
}
