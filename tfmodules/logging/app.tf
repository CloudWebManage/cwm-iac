module "app" {
  source = "../argocd-app"
  name = "logging"
  create_namespace = false
  autosync = true
  values = {
    tenant = {
      ingress = {
        api = {
          enabled = true
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt"
          }
          host = "logging-minio-tenant-api.${var.ingress_star_domain}"
          tls = [
            {
              hosts = ["logging-minio-tenant-api.${var.ingress_star_domain}"]
              secretName = "logging-minio-tenant-api-tls"
            }
          ]
        }
        console = {
          enabled = true
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt"
          }
          host = "logging-minio-tenant-console.${var.ingress_star_domain}"
          tls = [
            {
              hosts = ["logging-minio-tenant-console.${var.ingress_star_domain}"]
              secretName = "logging-minio-tenant-console-tls"
            }
          ]
        }
      }
      tenant = {
        name = "logging"
        configSecret = {
          name = kubernetes_secret.tenant-env-config.metadata[0].name
          existingSecret = true
        }
        certificate = {
          requestAutoCert = false
        }
        pools = [
          {
            name             = "logging1"
            servers          = 1
            volumesPerServer = 1
            volumeSize       = "999Gi"
            storageClassName = "directpv-min-io"
            tolerations = [
              {
                key      = "cwm-iac-worker-role"
                operator = "Equal"
                value    = "logging"
                effect   = "NoExecute"
              }
            ]
          }
        ]
      }
    }
    loki = {
      loki = {
        storage_config = {
          aws = {
            s3 = "http://${random_password.tenant-admin-user.result}:${random_password.tenant-admin-password.result}@minio.logging.svc.cluster.local"
          }
        }
      }
    }
  }
}
