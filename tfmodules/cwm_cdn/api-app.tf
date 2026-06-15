locals {
  cdn_pop_id = var.pop_id == "" ? var.name_prefix : var.pop_id
  cache_admin_endpoints = [
    for name in sort(keys(var.cache_servers)) : "${name}=http://${name}.cdn-cache:${var.cache_admin_port}"
  ]
}

data "vault_kv_secret_v2" "allowed_primary_key" {
  count = var.is_primary ? 0 : 1
  mount = var.vault_mount
  name  = "cwm-worker-cluster/${var.allowed_primary_cluster_name}/cwm_cdn/cwm_cdn_api_primary_key"
}

module "api_app" {
  source           = "../argocd-app"
  name             = "cdn-api"
  create_namespace = false
  tools            = var.tools
  kubeconfig_path  = var.kubeconfig_path
  depends_on       = [kubernetes_manifest.cache_admin_token_external_secret]
  values = merge(
    {
      isPrimary         = var.is_primary
      allowedPrimaryKey = var.is_primary ? random_password.primary_key[0].result : data.vault_kv_secret_v2.allowed_primary_key[0].data["key"]
      vmagent = {
        clusterLabel = var.name_prefix
        remoteWrite  = var.vmagentRemoteWriteConfig
      }
      popId = local.cdn_pop_id
      cacheAdmin = {
        enabled         = var.cache_admin_enabled
        tokenSecretName = var.cache_admin_token_secret_name
        tokenSecretKey  = var.cache_admin_token_secret_key
        endpoints       = local.cache_admin_endpoints
      }
      secondaries = {
        jsonSecretName = "cwm-cdn-tenants-config"
        jsonSecretKey  = "apiSecondaries.json"
      }
      policy = {
        enabled = var.cdn_policy_enabled
        trustedClientIp = {
          enabled           = var.cdn_trusted_client_ip_enabled
          trustedProxyCidrs = var.cdn_trusted_proxy_cidrs
        }
        captcha = {
          egressEnabled = var.cdn_captcha_egress_enabled
        }
      }
      logs = {
        structured = var.cdn_structured_logs_enabled
        platform   = var.cdn_platform_logs_enabled
      }
      popHealth = {
        enabled = var.cdn_pop_health_enabled
      }
      route53DnsAutomation = {
        enabled = var.route53_pop_health_dns_automation_enabled
        dryRun  = var.route53_pop_health_dns_dry_run_enabled
      }
    },
    (var.versions["cwm-cdn-api"] == "latest" || startswith(var.versions["cwm-cdn-api"], "config/")) ? {} : {
      cwmCdnApi = {
        api = {
          image = "ghcr.io/cloudwebmanage/cwm-cdn-api:${var.versions["cwm-cdn-api"]}"
        }
      }
    }
  )
  configSource = var.argocdConfigSource
  configValueFiles = var.versions["cwm-cdn-api"] == "latest" ? [
    "config/auto-updated/cwm-cdn-api/api.yaml"
    ] : (
    startswith(var.versions["cwm-cdn-api"], "config/") ? [
      "${var.versions["cwm-cdn-api"]}/cwm-cdn-api/api.yaml"
    ] : []
  )
  autosync = var.argocd_autosync
}

resource "random_password" "primary_key" {
  count   = var.is_primary ? 1 : 0
  length  = 32
  special = false
}

resource "vault_kv_secret_v2" "primary_key" {
  count      = var.is_primary ? 1 : 0
  depends_on = [random_password.primary_key]
  mount      = var.vault_mount
  name       = "${var.vault_path}/cwm_cdn_api_primary_key"
  data_json = jsonencode({
    key = random_password.primary_key[0].result
  })
}

resource "kubernetes_manifest" "cwm_cdn_tenants_config_external_secret" {
  count      = var.is_primary ? 1 : 0
  depends_on = [kubernetes_namespace.namespaces]
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "cwm-cdn-tenants-config"
      namespace = "cdn-api"
    }
    spec = {
      secretStoreRef = {
        name = "vault"
        kind = "ClusterSecretStore"
      }
      target = {
        template = {
          metadata = {
            annotations = {
              "cdn.cloudwm-cdn.com/config" = "true"
            }
          }
          data = {
            "primaryKey" = random_password.primary_key[0].result
            "secondaries.json" = jsonencode({
              for name, config in var.secondaries : name => {
                url  = "https://cwm-cdn-api.${config.cluster_name}.${var.zone_domain}"
                user = "{{ .${name}_user }}"
                pass = "{{ .${name}_pass }}"
              }
            })
            "apiSecondaries.json" = jsonencode([
              for name, config in var.secondaries : {
                name     = name
                url      = "https://cwm-cdn-api.${config.cluster_name}.${var.zone_domain}"
                username = "{{ .${name}_user }}"
                password = "{{ .${name}_pass }}"
              }
            ])
          }
        }
      }
      data = concat(
        [
          for name, config in var.secondaries : {
            secretKey = "${name}_user"
            remoteRef = {
              key      = "cwm-worker-cluster/${config.cluster_name}/cwm_cdn/cwm_cdn_api_creds"
              property = "username"
            }
          }
        ],
        [
          for name, config in var.secondaries : {
            secretKey = "${name}_pass"
            remoteRef = {
              key      = "cwm-worker-cluster/${config.cluster_name}/cwm_cdn/cwm_cdn_api_creds"
              property = "password"
            }
          }
        ]
      )
    }
  }
}
