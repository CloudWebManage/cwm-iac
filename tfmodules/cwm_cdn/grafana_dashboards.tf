module "grafana-dashboards-app" {
  source           = "../argocd-app"
  name             = "cdn-grafana-dashboards"
  namespace        = "monitoring"
  create_namespace = false
  versions = var.versions
  targetRevisionFromVersionByName = true
  path = "apps/grafana-dashboards"
  tools = var.tools
  kubeconfig_path = var.kubeconfig_path
  autosync = var.argocd_autosync
  values = {
    cdn = {
      enabled = true
    }
  }
}
