resource "random_password" "monitoring_grafana_admin_user" {
  length           = 8
  special          = false
}

resource "random_password" "monitoring_grafana_admin_password" {
  length           = 16
  special          = false
}

resource "vault_kv_secret_v2" "monitoring_grafana_admin" {
  depends_on = [random_password.monitoring_grafana_admin_password, random_password.monitoring_grafana_admin_user]
  mount = var.vault_mount
  name  = "${var.vault_path}/monitoring/grafana_admin"
  data_json = jsonencode({
    url = "https://grafana.${var.ingress_star_domain}"
    user = random_password.monitoring_grafana_admin_user.result
    password = random_password.monitoring_grafana_admin_password.result
  })
}

resource "kubernetes_manifest" "monitoring_grafana_admin_password" {
  depends_on = [kubernetes_namespace.monitoring]
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind = "ExternalSecret"
    metadata = {
      name      = "grafana-admin-password"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
    }
    spec = {
      secretStoreRef = {
        name = "vault"
        kind = "ClusterSecretStore"
      }
      data = [
        {
          secretKey = "admin-user"
          remoteRef = {
            key = "${var.vault_path}/monitoring/grafana_admin"
            property = "user"
          }
        },
        {
          secretKey = "admin-password"
          remoteRef = {
            key = "${var.vault_path}/monitoring/grafana_admin"
            property = "password"
          }
        }
      ]
    }
  }
}
