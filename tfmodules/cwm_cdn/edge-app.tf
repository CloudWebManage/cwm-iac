locals {
  cdn_edge_values = merge(
    {
      acmeHttp01 = {
        upstreamScheme = "http"
        upstreamHost   = var.is_primary ? "acme-ingress-upstream.kube-system.svc.cluster.local" : "edge.${var.allowed_primary_cluster_name}.${var.zone_domain}"
        upstreamPort   = 80
      }
    },
    (var.versions["cwm-cdn-edge-openresty"] == "latest" || startswith(var.versions["cwm-cdn-edge-openresty"], "config/")) ? {} : {
      cwmIac = {
        openresty = {
          image = "ghcr.io/cloudwebmanage/cwm-iac-openresty:${var.versions["cwm-cdn-edge-openresty"]}"
        }
      }
    }
  )
}

module "edge-app" {
  source           = "../argocd-app"
  name             = "cdn-edge"
  create_namespace = false
  tools            = var.tools
  versions         = var.versions
  kubeconfig_path  = var.kubeconfig_path
  values           = local.cdn_edge_values
  configSource     = var.argocdConfigSource
  configValueFiles = var.versions["cwm-cdn-edge-openresty"] == "latest" ? [
    "config/auto-updated/cwm-iac/openresty.yaml"
    ] : (
    startswith(var.versions["cwm-cdn-edge-openresty"], "config/") ? [
      "${var.versions["cwm-cdn-edge-openresty"]}/cwm-iac/openresty.yaml"
    ] : null
  )
  autosync                        = var.argocd_autosync
  targetRevisionFromVersionByName = true
}
