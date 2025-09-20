resource "random_password" "api-username" {
  length = 8
  special = false
}
resource "random_password" "api-password" {
  length = 24
  special = false
}

resource "null_resource" "api_creds" {
  triggers = {
    command = <<-EOT
      htpasswd -bn "${random_password.api-username.result}" "${random_password.api-password.result}" \
        | ${var.tools.vault} kv put -mount=${var.vault_mount} ${var.vault_path}/api_creds \
          auth=- \
          username="${random_password.api-username.result}" \
          password="${random_password.api-password.result}"
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}

resource "kubernetes_manifest" "cwm_minio_api_htpasswd_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind = "ExternalSecret"
    metadata = {
      name      = "cwm-minio-api-htpasswd"
      namespace = kubernetes_namespace.tenant.metadata[0].name
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
            key = "${var.vault_path}/api_creds"
            property = "auth"
          }
        }
      ]
    }
  }
}
