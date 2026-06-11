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

module "keda-app" {
  count            = var.keda_enabled ? 1 : 0
  source           = "../argocd-app"
  name             = "keda"
  namespace        = "keda"
  create_namespace = true
  tools            = var.tools
  kubeconfig_path  = var.admin_kubeconfig_path
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
