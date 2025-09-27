locals {
  kubeconfig = yamldecode(file(var.admin_kubeconfig_path))
}

data "kubernetes_secret" "vault_k8s_issuer" {
  metadata {
    name      = "vault-k8s-issuer"
    namespace = "kube-system"
  }
}

resource "vault_kubernetes_secret_backend" "k8s" {
  path = "/k8s-${var.name_prefix}"
  kubernetes_host = local.kubeconfig.clusters[0].cluster.server
  kubernetes_ca_cert = base64decode(local.kubeconfig.clusters[0].cluster.certificate-authority-data)
  service_account_jwt = data.kubernetes_secret.vault_k8s_issuer.data.token
  disable_local_ca_jwt = true
}

resource "vault_kubernetes_secret_backend_role" "github_actions" {
  backend = vault_kubernetes_secret_backend.k8s.path
  name = "github-actions"
  allowed_kubernetes_namespaces = ["kube-system"]
  service_account_name = "github-actions"
}

resource "vault_kv_secret_v2" "kubeconfig_template" {
  mount = var.vault_mount
  name = "${var.vault_path}/kubeconfig-template"
  data_json = jsonencode({
    kubeconfig = {
      apiVersion = "v1"
      kind = "Config"
      clusters = [
        {
          name = "default"
          cluster = {
            server = local.kubeconfig.clusters[0].cluster.server
            "certificate-authority-data" = local.kubeconfig.clusters[0].cluster.certificate-authority-data
          }
        }
      ]
      contexts = [
        {
          name = "default"
          context = {
            cluster = "default"
            user = "default"
          }
        }
      ]
      "current-context" = "default"
      users = [
        {
          name = "default"
          user = {
            token = "__K8S_TOKEN__"
          }
        }
      ]
    }
  })
}
