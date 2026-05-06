module "edge-app" {
  source = "../argocd-app"
  name = "cdn-edge"
  create_namespace = false
  tools = var.tools
  kubeconfig_path = var.kubeconfig_path
  values = (var.versions["cwm-cdn-edge-openresty"] == "latest" || startswith(var.versions["cwm-cdn-edge-openresty"], "config/")) ? null : {
    cwmIac = {
      openresty = {
        image = "ghcr.io/cloudwebmanage/cwm-iac-openresty:${var.versions["cwm-cdn-edge-openresty"]}"
      }
    }
  }
  configSource = var.argocdConfigSource
  configValueFiles = var.versions["cwm-cdn-edge-openresty"] == "latest" ? [
    "config/auto-updated/cwm-iac/openresty.yaml"
  ] : (
    startswith(var.versions["cwm-cdn-edge-openresty"], "config/") ? [
      "${var.versions["cwm-cdn-edge-openresty"]}/cwm-iac/openresty.yaml"
    ] : null
  )
  autosync = var.argocd_autosync
}
