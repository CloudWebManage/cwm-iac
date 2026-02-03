module "app" {
  source           = "../argocd-app"
  name             = "grafana-dashboards"
  namespace        = "monitoring"
  create_namespace = false
  autosync = true
  values = {
    minio = {
      prometheusUrl = "http://minio-tenant-${var.name}-metrics-prometheus-server.minio-tenant-${var.name}-metrics:80"
      namespaces = {
        tenant   = "minio-tenant-${var.name}"
        metrics  = "minio-tenant-${var.name}-metrics"
      }
    }
  }
}
