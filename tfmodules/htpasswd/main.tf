variable "vault_mount" {
  type = string
}

variable "vault_path" {
  type = string
}

variable "secrets" {
  type = list(object({
    name  = string
    namespace = string
  }))
}

variable "tools" {
  type = any
}

resource "random_password" "username" {
  length = 8
  special = false
}
resource "random_password" "password" {
  length = 24
  special = false
}

resource "null_resource" "htpasswd_vault" {
  triggers = {
    command = <<-EOT
      htpasswd -bn "${random_password.username.result}" "${random_password.password.result}" \
        | ${var.tools.vault} kv put -mount=${var.vault_mount} ${var.vault_path} \
          auth=- \
          username="${random_password.username.result}" \
          password="${random_password.password.result}"
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}

resource "kubernetes_manifest" "htpasswd_external_secret" {
  depends_on = [null_resource.htpasswd_vault]
  for_each = {for secret in var.secrets : "${secret.name}-${secret.namespace}" => secret}
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind = "ExternalSecret"
    metadata = {
      name      = each.value.name
      namespace = each.value.namespace
    }
    spec = {
      secretStoreRef = {
        name = "vault"
        kind = "ClusterSecretStore"
      }
      data = [
        {
          secretKey = "auth"
          remoteRef = {
            key = var.vault_path
            property = "auth"
          }
        }
      ]
    }
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
