module "cluster-grafana-dashboards-app" {
  source           = "../argocd-app"
  name             = "cluster-grafana-dashboards"
  namespace        = "monitoring"
  create_namespace = false
  path = "apps/grafana-dashboards"
  autosync = true
  values = {
    nginxIngress = {
      enabled = true
    }
  }
}
