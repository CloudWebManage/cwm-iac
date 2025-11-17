module "minio_tenant_main" {
  source = "../argocd-app"
  name = "minio-tenant-${var.name}"
  create_namespace = false
  path = "apps/minio-tenant"
  values = merge(
    {
      initialize = var.initialize
      tenant = {
        ingress = {
          api = {
            enabled = true
            annotations = {
              "cert-manager.io/cluster-issuer" = "letsencrypt"
              "nginx.ingress.kubernetes.io/proxy-body-size" = "5g"
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
              "nginx.ingress.kubernetes.io/whitelist-source-range" = var.console_ingress_whitelist_source_range
              "nginx.ingress.kubernetes.io/proxy-body-size" = "5g"
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
            name           = kubernetes_secret.env-config.metadata[0].name
            existingSecret = true
          }
          certificate = {
            requestAutoCert = false
          }
          pools = [
            for name, pool in var.pools : merge({
              name             = name
              servers          = 1
              volumesPerServer = 1
              volumeSize       = "999Gi"
              storageClassName = "directpv-min-io"
              labels = {
                "cwm-minio-tenant" = "true"
              }
              tolerations = [
                {
                  key      = "cwm-iac-worker-role"
                  operator = "Equal"
                  value    = "minio"
                  effect   = "NoExecute"
                }
              ]
            }, pool)
          ]
        }
      }
    },
    startswith(var.versions["cwm-minio-api"], "config/") ? {} : {
      cwmMinioApi = {
        api = {
          image = "ghcr.io/cloudwebmanage/cwm-minio-api:${var.versions["cwm-minio-api"]}"
        }
      }
    }
  )
  configSource = var.argocdConfigSource
  configValueFiles = startswith(var.versions["cwm-minio-api"], "config/") ? [
    "${var.versions["cwm-minio-api"]}/cwm-minio-api/api.yaml"
  ] : null
  autosync = true
}
