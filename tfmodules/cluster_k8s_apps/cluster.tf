module "cluster-app" {
  source = "../argocd-app"
  name = "cluster"
  namespace = "default"
  create_namespace = false
  autosync = var.argocd_autosync
  kubeconfig_path = var.admin_kubeconfig_path
  tools = var.tools
}
