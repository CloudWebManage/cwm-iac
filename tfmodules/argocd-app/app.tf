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
          var.values == null ? {} : {values = yamlencode(var.values)},
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

resource "terraform_data" "app" {
  triggers_replace = {
    command = nonsensitive(<<-EOT
set -euo pipefail
export KUBECONFIG=${var.kubeconfig_path}
cat <<'EOF' | ${var.tools.kubectl} replace --force --grace-period=0 -f -
${yamlencode(local.manifest)}
EOF
EOT
)
  }
  provisioner "local-exec" {
    command = self.triggers_replace.command
    interpreter = ["bash", "-c"]
   }
}
