resource "kubernetes_namespace" "tenant" {
  metadata {
    name = "minio-tenant-${var.name}"
  }
}
