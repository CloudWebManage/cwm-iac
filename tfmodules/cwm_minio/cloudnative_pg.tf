module "cloudnative_pg" {
  count = var.with_cloudnative_pg ? 1 : 0
  source = "../argocd-app"
  name = "cloudnative-pg"
  versions = var.versions
  targetRevisionFromVersionByName = true
  autosync = var.argocd_autosync
  sync_policy = {
    syncOptions : [
      "ServerSideApply=true"
    ]
  }
  tools = var.tools
  kubeconfig_path = var.kubeconfig_path
}
