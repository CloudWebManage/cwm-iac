resource "kubernetes_namespace" "namespaces" {
  for_each = toset(["cdn-edge", "cdn-api", "cdn-cache"])
  metadata {
    name = each.key
  }
}
