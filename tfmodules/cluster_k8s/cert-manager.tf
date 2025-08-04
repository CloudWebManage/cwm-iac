locals {
  certmanager_patch_deploymens = join("\n", [for o in [
    {name: "cert-manager"},
    {name: "cert-manager-cainjector"},
    {name: "cert-manager-webhook"},
  ] : <<-EOT
    - target:
        kind: ${lookup(o, "kind", "Deployment")}
        name: ${o.name}
      patch: |
        apiVersion: apps/v1
        kind: ${lookup(o, "kind", "Deployment")}
        metadata:
          name: ${o.name}
        spec:
          template:
            spec:
              tolerations:
              - key: "cwm-iac-worker-role"
                operator: "Equal"
                value: "system"
                effect: "NoExecute"
  EOT
  ])
  certmanager_kustomization_yaml = <<-EOT
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization

    resources:
    - install-${var.certmanager_version}.yaml

    patches:
    ${local.certmanager_patch_deploymens}
  EOT
}

resource "null_resource" "certmanager_install" {
  triggers = {
    counter = lookup(var.force_reinstall_counters, "cert-manager", 0)
    command = <<-EOT
      set -euo pipefail
      mkdir -p "${var.data_path}/cert-manager"
      if ! [ -f "${var.data_path}/cert-manager/install-${var.certmanager_version}.yaml" ]; then
        curl -L -o "${var.data_path}/cert-manager/install-${var.certmanager_version}.yaml" \
          https://github.com/jetstack/cert-manager/releases/download/v${var.certmanager_version}/cert-manager.yaml
      fi
      echo '${local.certmanager_kustomization_yaml}' > "${var.data_path}/cert-manager/kustomization.yaml"
      ${local.kubectl} apply -k "${var.data_path}/cert-manager"
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}

resource "kubernetes_manifest" "certmanager_cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt"
    }
    spec = {
      acme = {
        server          = "https://acme-v02.api.letsencrypt.org/directory"
        email           = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-issuer-private-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                ingressClassName: "nginx"
                podTemplate = {
                  spec = {
                    tolerations = [
                      {
                        key      = "cwm-iac-worker-role"
                        operator = "Equal"
                        value    = "system"
                        effect   = "NoExecute"
                      }
                    ]
                  }
                }
              }
            }
          }
        ]
      }
    }
  }
}
