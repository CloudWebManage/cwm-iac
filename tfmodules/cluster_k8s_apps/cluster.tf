module "cluster-app" {
  source = "../argocd-app"
  name = "cluster"
  namespace = "default"
  create_namespace = false
  autosync = true
}
