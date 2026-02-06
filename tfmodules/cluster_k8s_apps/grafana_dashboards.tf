module "cluster-grafana-dashboards-app" {
  source           = "../argocd-app"
  name             = "cluster-grafana-dashboards"
  namespace        = "monitoring"
  create_namespace = false
  versions = var.versions
  targetRevisionFromVersionByName = true
  path = "apps/grafana-dashboards"
  autosync = true
  values = {
    nginxIngress = {
      enabled = true
    }
  }
}
