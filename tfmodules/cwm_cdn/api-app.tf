module "api_app" {
  source = "../../tfmodules/argocd-app"
  name = "cdn-api"
}
