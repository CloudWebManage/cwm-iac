resource "kubernetes_namespace" "app" {
  count = var.create_namespace ? 1 : 0
  metadata {
    name = coalesce(var.namespace, var.name)
  }
}
