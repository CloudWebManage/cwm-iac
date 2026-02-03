module "etcd" {
  source = "../argocd-app"
  name = "minio-${var.name}-etcd"
  path = "apps/etcd"
  namespace = kubernetes_namespace.tenant.metadata[0].name
  create_namespace = false
  sync_policy = {
    automated = {
      prune = true
      selfHeal = true
    }
  }
}
