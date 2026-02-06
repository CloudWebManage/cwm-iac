module "cloudnative_pg" {
  count = var.with_cloudnative_pg ? 1 : 0
  source = "../argocd-app"
  name = "cloudnative-pg"
  versions = var.versions
  targetRevisionFromVersionByName = true
  sync_policy = {
    automated = {
      prune = true
      selfHeal = true
    }
    syncOptions : [
      "ServerSideApply=true"
    ]
  }
}
