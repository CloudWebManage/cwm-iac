locals {
  configValueFiles = concat(
      (startswith(var.versions["cwm-minio-api"], "config/") ? ["${var.versions["cwm-minio-api"]}/cwm-minio-api/api.yaml"] : []),
      (startswith(var.versions["cwm-minio-tierer"], "config/") ? ["${var.versions["cwm-minio-tierer"]}/cwm-minio-tierer/tierer.yaml"] : []),
  )
  tiererAccessRetentionHours = max(var.tierer_config.low_hours, var.tierer_config.high_hours) + 5
  tierer = {
    low_hours = var.tierer_config.low_hours
    low_threshold = var.tierer_config.low_threshold
    high_hours = var.tierer_config.high_hours
    high_threshold = var.tierer_config.high_threshold
    access_retention_hours = local.tiererAccessRetentionHours
    access_retention = "${local.tiererAccessRetentionHours}h"
    chunk_size = floor(10000 / (var.tierer_config.low_hours + var.tierer_config.high_hours))
  }
}

module "minio_tenant_main" {
  source = "../argocd-app"
  name = "minio-tenant-${var.name}"
  create_namespace = false
  path = "apps/minio-tenant"
  versions = var.versions
  targetRevisionFromVersionByName = true
  tools = var.tools
  kubeconfig_path = var.kubeconfig_path
  values = merge(
    {
      initialize = var.initialize
      nodeLocal = {
        enabled = var.node_local_enabled
      }
      clusterName = var.cluster_name
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
              size       = "999Gi"
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
          ],
          additionalVolumes = [
            {
              name = "host-var-lib-minio"
              hostPath = {
                path = "/var/lib/minio/"
                type = "DirectoryOrCreate"
              }
            }
          ]
          additionalVolumeMounts = [
            {
              name      = "host-var-lib-minio"
              mountPath = "/host/var/lib/minio/"
            }
          ]
          initContainers = [
            {
              name = "init-host-perms"
              image = "busybox:1.37"
              command = ["sh", "-c", "chown 1000:1000 /var/lib/vector /var/lib/minio"]
              securityContext = {
                runAsUser  = 0
                runAsGroup = 0
                runAsNonRoot = false
              }
              volumeMounts = [
                {
                  name      = "host-var-lab-vector"
                  mountPath = "/var/lib/vector/"
                },
                {
                  name      = "host-var-lib-minio"
                  mountPath = "/var/lib/minio/"
                }
              ]
            }
          ]
          sideCars = {
            volumes = [
              {
                name = "host-var-lab-vector"
                hostPath = {
                  path = "/var/lib/vector/"
                  type = "DirectoryOrCreate"
                }
              }
            ]
            containers = [
              {
                name = "cwm-iac-minio-log-metrics"
                image = var.log_metrics_sidecar_image
                volumeMounts = [
                  {
                    name      = "host-var-lab-vector"
                    mountPath = "/var/lib/vector/"
                  }
                ]
              },
              {
                name = "cwm-minio-tierer-access-updater"
                image = var.minio_tierer_image
                command = ["/usr/local/bin/redis-updater"]
                env = [
                  {name = "INSTANCE_ID", value = var.name},
                  {name = "ACCESS_RETENTION", value = local.tierer.access_retention},
                  {name = "UPDATER_LISTEN_ADDR", value = "127.0.0.1:8921"},
                  {name = "REDIS_ADDR", value = "tierer-redis:6379"},
                  {name = "UPDATER_MAX_BODY_BYTES", value = "1073741824"},
                  {name = "UPDATER_MAX_RECORDS", value = "1000000"},
                  {name = "UPDATER_BATCH_MAX_EVENTS", value = "1000000"},
                  {name = "UPDATER_BATCH_MAX_KEYS", value = "1000000"},
                ]
              }
            ]
          }
        }
      }
      tierer = local.tierer
      low_tier_s3 = var.low_tier_s3
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
  configValueFiles = length(local.configValueFiles) > 0 ? local.configValueFiles : null
  autosync = var.argocd_autosync
}
