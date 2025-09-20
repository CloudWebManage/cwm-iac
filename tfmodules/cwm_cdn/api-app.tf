module "api_app" {
  source = "../argocd-app"
  name = "cdn-api"
  create_namespace = false
}
