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
        | ${var.tools.vault} kv put -mount=${var.vault_mount} ${var.vault_path}/cwm_cdn_api_creds \
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

resource "kubernetes_manifest" "api_htpasswd_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind = "ExternalSecret"
    metadata = {
      name      = "cwm-cdn-api-htpasswd"
      namespace = "cdn-api"
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
            key = "${var.vault_path}/cwm_cdn_api_creds"
            property = "auth"
          }
        }
      ]
    }
  }
}

resource "kubernetes_ingress_v1" "cwm-cdn-api" {
  metadata {
    name = "cwm-cdn-api"
    namespace = "cdn-api"
    annotations = {
      "cert-manager.io/cluster-issuer": "letsencrypt"
      "nginx.ingress.kubernetes.io/auth-type": "basic"
      "nginx.ingress.kubernetes.io/auth-secret": "cwm-cdn-api-htpasswd"
      "nginx.ingress.kubernetes.io/auth-realm": "Protected Area"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = ["cwm-cdn-api.${var.name_prefix}.${var.ingress_dns_zone_domain}"]
      secret_name = "cwm-cdn-api-tls"
    }
    rule {
      host = "cwm-cdn-api.${var.name_prefix}.${var.ingress_dns_zone_domain}"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "cdn-api"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }
}
