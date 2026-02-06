module "tenant-grafana-dashboards-app" {
  source           = "../argocd-app"
  name             = "minio-tenant-${var.name}-grafana-dashboards"
  namespace        = "monitoring"
  create_namespace = false
  versions = var.versions
  targetRevisionFromVersionByName = true
  path = "apps/grafana-dashboards"
  autosync = true
  values = {
    minio = {
      enabled = true
      prometheusUrl = "http://minio-tenant-${var.name}-metrics-prometheus-server.minio-tenant-${var.name}-metrics:80"
      namespaces = {
        tenant   = "minio-tenant-${var.name}"
        metrics  = "minio-tenant-${var.name}-metrics"
      }
    }
  }
}
