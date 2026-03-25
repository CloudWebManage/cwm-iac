resource "kubernetes_namespace" "vmaggregator" {
  metadata {
    name = "vmaggregator"
  }
}


module "app" {
  depends_on = [kubernetes_namespace.vmaggregator]
  source = "../argocd-app"
  name = "vmaggregator"
  create_namespace = false
  tools = var.tools
  kubeconfig_path = var.admin_kubeconfig_path
  values = {}
  sync_policy = {
    # automated = {
    #   prune = true
    #   selfHeal = true
    # }
    syncOptions = [
      "ServerSideApply=true"
    ]
  }
}
