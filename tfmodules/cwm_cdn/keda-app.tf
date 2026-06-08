locals {
  keda_system_tolerations = [
    {
      key      = "cwm-iac-worker-role"
      operator = "Equal"
      value    = "system"
      effect   = "NoExecute"
    }
  ]
}

module "keda_app" {
  depends_on       = [kubernetes_namespace.namespaces]
  source           = "../argocd-app"
  name             = "keda"
  namespace        = "keda"
  create_namespace = false
  tools            = var.tools
  kubeconfig_path  = var.kubeconfig_path
  sources = [
    {
      repoURL        = "https://kedacore.github.io/charts"
      chart          = "keda"
      targetRevision = var.versions["keda"]
      helm = {
        values = yamlencode({
          crds = {
            install = true
            keep    = true
          }
          operator = {
            tolerations = local.keda_system_tolerations
          }
          metricsServer = {
            tolerations = local.keda_system_tolerations
          }
          webhooks = {
            tolerations = local.keda_system_tolerations
          }
        })
      }
    }
  ]
  autosync = var.argocd_autosync
}
