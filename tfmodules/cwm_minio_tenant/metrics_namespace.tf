resource "kubernetes_namespace" "minio-tenant-metrics" {
  metadata {
    name = "minio-tenant-${var.name}-metrics"
  }
}
