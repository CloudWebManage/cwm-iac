module "cloudnative_pg" {
  count = var.with_cloudnative_pg ? 1 : 0
  source = "../argocd-app"
  name = "cloudnative-pg"
  sync_policy = {
    syncOptions : [
      "ServerSideApply=true"
    ]
  }
}
