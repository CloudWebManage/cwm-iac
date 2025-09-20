module "cache-app" {
  source = "../argocd-app"
  name = "cdn-cache"
  create_namespace = false
}
