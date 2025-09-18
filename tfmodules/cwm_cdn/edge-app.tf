module "edge-app" {
  source = "../../tfmodules/argocd-app"
  name = "cdn-edge"
}
