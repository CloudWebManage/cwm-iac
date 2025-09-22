module "cache-app" {
  source = "../argocd-app"
  name = "cdn-cache"
  create_namespace = false
  values = var.versions["cwm-cdn-api-cache-nginx"] == "latest" ? null : {
    cwmCdnApi = {
      cacheNginx = {
        image = "ghcr.io/cloudwebmanage/cwm-cdn-api-cache-nginx:${var.versions["cwm-cdn-api-cache-nginx"]}"
      }
    }
  }
  configSource = var.argocdConfigSource
  configValueFiles = var.versions["cwm-cdn-api-cache-nginx"] == "latest" ? [
    "config/auto-updated/cwm-cdn-api/cache-nginx.yaml"
  ] : []
  autosync = true
}
