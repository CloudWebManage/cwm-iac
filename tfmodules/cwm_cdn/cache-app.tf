resource "random_password" "cache_admin_token" {
  length  = 48
  special = false
}

resource "vault_kv_secret_v2" "cache_admin_token" {
  depends_on = [random_password.cache_admin_token]
  mount      = var.vault_mount
  name       = "${var.vault_path}/cdn_cache_admin_token"
  data_json = jsonencode({
    token = random_password.cache_admin_token.result
  })
}

resource "kubernetes_manifest" "cache_admin_token_external_secret" {
  for_each   = toset(["cdn-api", "cdn-cache"])
  depends_on = [kubernetes_namespace.namespaces, vault_kv_secret_v2.cache_admin_token]
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = var.cache_admin_token_secret_name
      namespace = each.key
    }
    spec = {
      secretStoreRef = {
        name = "vault"
        kind = "ClusterSecretStore"
      }
      target = {
        name = var.cache_admin_token_secret_name
      }
      data = [
        {
          secretKey = var.cache_admin_token_secret_key
          remoteRef = {
            key      = "${var.vault_path}/cdn_cache_admin_token"
            property = "token"
          }
        }
      ]
    }
  }
}

module "cache-app" {
  source           = "../argocd-app"
  name             = "cdn-cache"
  create_namespace = false
  tools            = var.tools
  versions         = var.versions
  targetRevisionFromVersionByName = true
  kubeconfig_path  = var.kubeconfig_path
  depends_on       = [kubernetes_manifest.cache_admin_token_external_secret]
  values = merge(
    {
      cacheServers = var.cache_servers
      cacheAdmin = {
        enabled         = var.cache_admin_enabled
        port            = var.cache_admin_port
        tokenSecretName = var.cache_admin_token_secret_name
        tokenSecretKey  = var.cache_admin_token_secret_key
        networkPolicy = {
          enabled         = var.cache_admin_network_policy_enabled
          cdnApiNamespace = "cdn-api"
          cdnApiPodSelector = {
            app = "cdn-api"
          }
          routerPodSelector = {
            app = "router"
          }
        }
      }
    },
    (var.versions["cwm-cdn-api-cache-nginx"] == "latest" || startswith(var.versions["cwm-cdn-api-cache-nginx"], "config/")) ? {} : {
      cwmCdnApi = {
        cacheNginx = {
          image = "ghcr.io/cloudwebmanage/cwm-cdn-api-cache-nginx:${var.versions["cwm-cdn-api-cache-nginx"]}"
        }
      }
    }
  )
  configSource = var.argocdConfigSource
  configValueFiles = var.versions["cwm-cdn-api-cache-nginx"] == "latest" ? [
    "config/auto-updated/cwm-cdn-api/cache-nginx.yaml"
    ] : (
    startswith(var.versions["cwm-cdn-api-cache-nginx"], "config/") ? [
      "${var.versions["cwm-cdn-api-cache-nginx"]}/cwm-cdn-api/cache-nginx.yaml"
    ] : []
  )
  autosync = var.argocd_autosync
}
