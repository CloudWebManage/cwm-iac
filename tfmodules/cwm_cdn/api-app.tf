data "vault_kv_secret_v2" "allowed_primary_key" {
  count = var.is_primary ? 0 : 1
  mount = var.vault_mount
  name  = "cwm-worker-cluster/${var.allowed_primary_cluster_name}/cwm_cdn/cwm_cdn_api_primary_key"
}

module "api_app" {
  source = "../argocd-app"
  name = "cdn-api"
  create_namespace = false
  values = merge(
    {
      isPrimary = var.is_primary
      allowedPrimaryKey = var.is_primary ? "" : data.vault_kv_secret_v2.allowed_primary_key[0].data["key"]
      vmagent = {
        clusterLabel = var.name_prefix
        remoteWrite = var.vmagentRemoteWriteConfig
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
  autosync = true
}

resource "random_password" "primary_key" {
  count = var.is_primary ? 1 : 0
  length = 32
  special = false
}

resource "vault_kv_secret_v2" "primary_key" {
  count = var.is_primary ? 1 : 0
  depends_on = [random_password.primary_key]
  mount = var.vault_mount
  name  = "${var.vault_path}/cwm_cdn_api_primary_key"
  data_json = jsonencode({
    key = random_password.primary_key[0].result
  })
}

resource "kubernetes_manifest" "cwm_cdn_tenants_config_external_secret" {
  count = var.is_primary ? 1 : 0
  depends_on = [kubernetes_namespace.namespaces]
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind = "ExternalSecret"
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
                url = "https://cwm-cdn-api.${config.cluster_name}.${var.zone_domain}"
                user = "{{ .${name}_user }}"
                pass = "{{ .${name}_pass }}"
              }
            })
          }
        }
      }
      data = concat(
        [
          for name, config in var.secondaries: {
            secretKey = "${name}_user"
            remoteRef = {
              key = "cwm-worker-cluster/${config.cluster_name}/cwm_cdn/cwm_cdn_api_creds"
              property = "username"
            }
          }
        ],
        [
          for name, config in var.secondaries: {
            secretKey = "${name}_pass"
            remoteRef = {
              key = "cwm-worker-cluster/${config.cluster_name}/cwm_cdn/cwm_cdn_api_creds"
              property = "password"
            }
          }
        ]
      )
    }
  }
}
