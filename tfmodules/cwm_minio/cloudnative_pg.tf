module "cloudnative_pg" {
  source = "../argocd-app"
  name = "cloudnative-pg"
  sync_policy = {
    syncOptions : [
      "ServerSideApply=true"
    ]
  }
}
