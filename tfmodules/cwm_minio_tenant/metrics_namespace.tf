resource "kubernetes_namespace" "minio-tenant-metrics" {
  count = var.metrics ? 1 : 0
  metadata {
    name = "minio-tenant-${var.name}-metrics"
  }
}
