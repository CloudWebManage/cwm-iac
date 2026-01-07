module "app" {
  source           = "../argocd-app"
  name             = "grafana-dashboards"
  namespace        = "monitoring"
  create_namespace = false
  targetRevision   = var.targetRevision
  values = {
    minioPrometheus = {
      url = "http://minio-tenant-${var.tenant_name}-metrics-prometheus-server.minio-tenant-${var.tenant_name}-metrics:80"
    }
    namespaces = {
      tenant   = "minio-tenant-${var.tenant_name}"
      metrics  = "minio-tenant-${var.tenant_name}-metrics"
      directpv = "directpv"
      operator = "minio-operator"
    }
    grafanaFolder = "MinIO"
  }
  sync_policy = {
    automated = {
      prune    = true
      selfHeal = true
    }
  }
}
