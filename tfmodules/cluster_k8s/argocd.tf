resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

locals {
  argocd_patch_deploymens = join("\n", [for o in [
    {name: "argocd-applicationset-controller"},
    {name: "argocd-dex-server"},
    {name: "argocd-notifications-controller"},
    {name: "argocd-redis"},
    {name: "argocd-repo-server"},
    {name: "argocd-server"},
    {name: "argocd-application-controller", kind: "StatefulSet"},
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
  argocd_kustomization_yaml = <<-EOT
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization

    resources:
    - install-${var.argocd_version}.yaml

    patches:
    - target:
        kind: ConfigMap
        name: argocd-cmd-params-cm
      patch: |
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: argocd-cmd-params-cm
        data:
          server.insecure: "true"
    ${local.argocd_patch_deploymens}
  EOT
}

resource "null_resource" "argocd_install" {
  depends_on = [kubernetes_namespace.argocd]
  triggers = {
    counter = lookup(var.force_reinstall_counters, "argocd", 0)
    command = <<-EOT
      set -euo pipefail
      mkdir -p "${var.data_path}/argocd"
      if ! [ -f "${var.data_path}/argocd/install-${var.argocd_version}.yaml" ]; then
        curl -L -o "${var.data_path}/argocd/install-${var.argocd_version}.yaml" \
          https://raw.githubusercontent.com/argoproj/argo-cd/v${var.argocd_version}/manifests/install.yaml
      fi
      echo '${local.argocd_kustomization_yaml}' > "${var.data_path}/argocd/kustomization.yaml"
      ${local.kubectl} apply -n argocd -k "${var.data_path}/argocd"
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}

output "argocd_admin" {
  value = {
    url = "https://argocd.${var.ingress_star_domain}"
    username = "admin"
    password = "${local.kubectl} -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode"
  }
}

resource "kubernetes_ingress_v1" "argocd-server" {
  metadata {
    name = "argocd-server"
    namespace = "argocd"
    annotations = {
      "cert-manager.io/cluster-issuer": "letsencrypt"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = ["argocd.${var.ingress_star_domain}"]
      secret_name = "argocd-tls"
    }
    rule {
      host = "argocd.${var.ingress_star_domain}"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                name = "http"
              }
            }
          }
        }
      }
    }
  }
}

resource "tls_private_key" "argocd_cwm_worker_cluster_deploy_key" {
  algorithm = "RSA"
}

# this is added manually so we don't have to manage GitHub credentials with Terraform
# resource "github_repository_deploy_key" "argocd_cwm_worker_cluster" {
#   repository = "cwm-worker-cluster"
#   title = "ArgoCD Deploy Key"
#   key = tls_private_key.argocd_cwm_worker_cluster_deploy_key.public_key_openssh
#   read_only = true
# }

output "argocd_cwm_worker_cluster_deploy_private_key" {
  value = tls_private_key.argocd_cwm_worker_cluster_deploy_key.private_key_pem
  sensitive = true
}
