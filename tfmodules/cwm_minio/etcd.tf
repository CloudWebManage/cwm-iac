module "etcd" {
  source = "../argocd-app"
  name = "etcd"
  sync_policy = {
    automated = {
      prune = true
      selfHeal = true
    }
  }
}
