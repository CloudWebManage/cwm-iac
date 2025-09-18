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
    - install-${var.versions["certmanager"]}.yaml
    - cluster-issuer.yaml

    patches:
    ${local.certmanager_patch_deploymens}
  EOT
}

resource "local_file" "certmanager_cluster_issuer" {
  filename = "${var.data_path}/cert-manager/cluster-issuer.yaml"
  content = yamlencode({
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
  })
}

resource "null_resource" "certmanager_install" {
  triggers = {
    counter = lookup(var.force_reinstall_counters, "cert-manager", 0)
    cluster_issuer = local_file.certmanager_cluster_issuer.content
    command = <<-EOT
      set -euo pipefail
      mkdir -p "${var.data_path}/cert-manager"
      if ! [ -f "${var.data_path}/cert-manager/install-${var.versions["certmanager"]}.yaml" ]; then
        curl -L -o "${var.data_path}/cert-manager/install-${var.versions["certmanager"]}.yaml" \
          https://github.com/jetstack/cert-manager/releases/download/v${var.versions["certmanager"]}/cert-manager.yaml
      fi
      echo '${local.certmanager_kustomization_yaml}' > "${var.data_path}/cert-manager/kustomization.yaml"
      if ! KUBECONFIG=${var.admin_kubeconfig_path} ${var.tools.kubectl} apply -k "${var.data_path}/cert-manager"; then
        echo waiting for cert-manager CRD to be installed...
        sleep 10
        KUBECONFIG=${var.admin_kubeconfig_path} ${var.tools.kubectl} apply -k "${var.data_path}/cert-manager"
      fi
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}
