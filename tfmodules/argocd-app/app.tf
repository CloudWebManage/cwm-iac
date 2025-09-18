locals {
  base_spec = {
    destination = {
      namespace = coalesce(var.namespace, var.name)
      server    = "https://kubernetes.default.svc"
    }
    project = var.project
  }
  sources_spec = var.sources == null ? {
    source = {
      repoURL        = "https://github.com/CloudWebManage/cwm-iac"
      targetRevision = var.targetRevision
      path           = coalesce(var.path, "apps/${var.name}")
      helm = {
        valuesObject = var.values
      }
    }
  } : {
    sources = var.sources
  }
  sync_policy_spec = merge(
    var.autosync == true ? {
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    } : {},
    var.sync_policy != null ? {
      syncPolicy = var.sync_policy
    } : {}
  )
}

resource "kubernetes_manifest" "app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.name
      namespace = "argocd"
    }
    spec = merge(local.base_spec, local.sources_spec, local.sync_policy_spec)
  }
}
