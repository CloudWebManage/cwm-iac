module "minio_tenant_main" {
  source = "../argocd-app"
  name = "minio-tenant-${var.name}"
  create_namespace = false
  path = "apps/minio-tenant"
  sources = concat([
    {
      repoURL        = "https://github.com/CloudWebManage/cwm-iac"
      targetRevision = "main"
      path           = "apps/minio-tenant"
      helm = merge({
        valuesObject = {
          initialize = var.initialize
          tenant = {
            ingress = {
              api = {
                enabled = true
                annotations = {
                  "cert-manager.io/cluster-issuer" = "letsencrypt"
                }
                host = "minio-tenant-${var.name}-api.${var.ingress_star_domain}"
                tls = [
                  {
                    hosts = ["minio-tenant-${var.name}-api.${var.ingress_star_domain}"]
                    secretName = "minio-tenant-${var.name}-api-tls"
                  }
                ]
              }
              console = {
                enabled = true
                annotations = {
                  "cert-manager.io/cluster-issuer" = "letsencrypt"
                }
                host = "minio-tenant-${var.name}-console.${var.ingress_star_domain}"
                tls = [
                  {
                    hosts = ["minio-tenant-${var.name}-console.${var.ingress_star_domain}"]
                    secretName = "minio-tenant-${var.name}-console-tls"
                  }
                ]
              }
            }
            tenant = {
              name = var.name
              image = {
                tag = var.minio_image_tag
              }
              configSecret = {
                name = kubernetes_secret.env-config.metadata[0].name
                existingSecret = true
              }
              certificate = {
                requestAutoCert = false
              }
              pools = [
                for name, pool in var.pools : merge({
                  name = name
                  servers = 1
                  volumesPerServer = 1
                  volumeSize = "999Gi"
                  storageClassName = "directpv-min-io"
                  labels = {
                    "cwm-minio-tenant" = "true"
                  }
                  tolerations = [
                    {
                      key = "cwm-iac-worker-role"
                      operator = "Equal"
                      value = "minio"
                      effect = "NoExecute"
                    }
                  ]
                }, pool)
              ]
            }
          }
        }
      }, var.app_helm_overrides)
    }
  ], var.app_extra_sources)
}
