locals {
  base_spec = {
    destination = {
      namespace = coalesce(var.namespace, var.name)
      server    = "https://kubernetes.default.svc"
    }
    project = var.project
  }
  source_spec = (var.sources == null && var.configValueFiles == null) ? {
    source = {
      repoURL        = "https://github.com/CloudWebManage/cwm-iac"
      targetRevision = coalesce(var.targetRevisionFromVersionByName ? lookup(var.versions, "cwm-iac-${var.name}", null) : null, var.targetRevision)
      path           = coalesce(var.path, "apps/${var.name}")
      helm = {
        values = yamlencode(var.values)
        valuesObject = null
      }
    }
  } : {}
  config_sources_spec = (var.configValueFiles != null && var.configSource != null) ? {
    sources = [
      {
        repoURL        = "https://github.com/CloudWebManage/cwm-iac"
        targetRevision = var.targetRevision
        path           = coalesce(var.path, "apps/${var.name}")
        helm = merge(
          var.values == null ? {valuesObject = null} : {values = yamlencode(var.values), valuesObject = null},
          {valueFiles = [for vf in var.configValueFiles : "$configValues/${vf}"]}
        )
      },
      merge(var.configSource, {ref = "configValues"})
    ]
  } : {}
  sources_spec = var.sources != null ? {
    sources = var.sources
  } : {}
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
  merged_spec = jsondecode(jsonencode(merge(local.base_spec, local.source_spec, local.config_sources_spec, local.sources_spec, local.sync_policy_spec)))
}

# resource "terraform_data" "debug_app_spec" {
#   triggers_replace = {
#     spec = nonsensitive(local.merged_spec)
#   }
# }

resource "kubernetes_manifest" "app" {
  field_manager {
    name = "cwm-iac-terraform-argocd-app"
    force_conflicts = true
  }
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.name
      namespace = "argocd"
    }
    spec = local.merged_spec
  }
}

# resource "terraform_data" "validate_app" {
#   triggers_replace = {
#     spec = local.merged_spec
#     command = <<-EOT
# set -euo pipefail
# if cat <<-EOF | grep valuesObject; then echo valuesObject is not supported must use values; exit 1; fi
# ${jsonencode(kubernetes_manifest.app.object.spec)}
# EOF
# echo spec is valid
# EOT
#   }
#   provisioner "local-exec" {
#     interpreter = ["bash", "-c"]
#     command = self.triggers_replace.command
#   }
# }