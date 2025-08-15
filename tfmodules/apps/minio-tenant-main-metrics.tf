resource "kubernetes_namespace" "minio-tenant-main-metrics" {
  metadata {
    name = "minio-tenant-main-metrics"
  }
}

locals {
  minio_tenant_main_metrics_values = {}
}

resource "kubernetes_manifest" "minio-tenant-main-metrics-app" {
  depends_on = [kubernetes_namespace.minio-tenant-main-metrics]
  manifest = yamldecode(<<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: minio-tenant-main-metrics
      namespace: argocd
    spec:
      destination:
        namespace: minio-tenant-main-metrics
        server: 'https://kubernetes.default.svc'
      project: default
      source:
        repoURL: https://github.com/CloudWebManage/cwm-iac
        targetRevision: main
        path: apps/minio-tenant-metrics
        helm:
          valuesObject: ${jsonencode(local.minio_tenant_main_metrics_values)}
  EOT
  )
}
