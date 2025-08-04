resource "kubernetes_namespace" "minio-tenant-main" {
  metadata {
    name = "minio-tenant-main"
  }
}

resource "random_password" "minio-tenant-main-root-user" {
  length = 8
}

resource "random_password" "minio-tenant-main-root-password" {
  length = 16
}

resource "kubernetes_secret" "minio-tenant-main-env-config" {
  metadata {
    name      = "tenant-env-configuration"
    namespace = kubernetes_namespace.minio-tenant-main.metadata[0].name
  }
  type = "Opaque"
  data = {
    "config.env": <<-EOT
      export MINIO_ROOT_USER=${ random_password.minio-tenant-main-root-user.result }
      export MINIO_ROOT_PASSWORD=${ random_password.minio-tenant-main-root-password.result }
    EOT
  }
}

locals {
  minio_tenant_main_values = {
    tenant = {
      ingress = {
        api = {
          enabled = true
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt"
          }
          host = "minio-tenant-main-api.${var.ingress_star_domain}"
          tls = [
            {
              hosts = ["minio-tenant-main-api.${var.ingress_star_domain}"]
              secretName = "minio-tenant-main-api-tls"
            }
          ]
        }
        console = {
          enabled = true
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt"
          }
          host = "minio-tenant-main-console.${var.ingress_star_domain}"
          tls = [
            {
              hosts = ["minio-tenant-main-console.${var.ingress_star_domain}"]
              secretName = "minio-tenant-main-console-tls"
            }
          ]
        }
      }
      tenant = {
        name = "main"
        image = {
          tag = "RELEASE.2025-07-23T15-54-02Z"
        }
        configSecret = {
          name = kubernetes_secret.minio-tenant-main-env-config.metadata[0].name
          existingSecret = true
        }
        certificate = {
          requestAutoCert = false
        }
        pools = [
          {
            name = "pool-1"
            servers = 1
            volumesPerServer = 1
            volumeSize = "999Gi"
            storageClassName = "directpv-min-io"
            tolerations = [
              {
                key = "cwm-iac-worker-role"
                operator = "Equal"
                value = "minio"
                effect = "NoExecute"
              }
            ]
          }
        ]
      }
    }
  }
}

resource "kubernetes_manifest" "minio-tenant-main-app" {
  manifest = yamldecode(<<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: minio-tenant-main
      namespace: argocd
    spec:
      destination:
        namespace: minio-tenant-main
        server: 'https://kubernetes.default.svc'
      project: default
      source:
        repoURL: https://github.com/CloudWebManage/cwm-iac
        targetRevision: main
        path: apps/minio-tenant
        helm:
          valuesObject: ${jsonencode(local.minio_tenant_main_values)}
  EOT
  )
}

output "minio_tenant_main" {
  value = {
    api_url = "https://minio-tenant-main-api.${var.ingress_star_domain}"
    console_url = "https://minio-tenant-main-console.${var.ingress_star_domain}"
    admin_username = random_password.minio-tenant-main-root-user.result
    admin_password = random_password.minio-tenant-main-root-password.result
  }
  sensitive = true
}
