resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

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

resource "kubernetes_manifest" "monitoring-app" {
  depends_on = [kubernetes_namespace.monitoring]
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "monitoring"
      namespace = "argocd"
    }
    spec = {
      destination = {
        namespace = kubernetes_namespace.monitoring.metadata[0].name
        server    = "https://kubernetes.default.svc"
      }
      project = "default"
      source = {
        repoURL        = "https://github.com/CloudWebManage/cwm-iac"
        targetRevision = "main"
        path           = "apps/monitoring"
        helm = {
          valuesObject = {
            "kube-prometheus-stack" = {
              alertmanager = {
                alertmanagerSpec = {
                  externalUrl = "https://alertmanager.${var.ingress_star_domain}"
                }
              }
              prometheus = {
                prometheusSpec = {
                  externalUrl = "https://prometheus.${var.ingress_star_domain}"
                }
              }
            }
          }
        }
      }
      syncPolicy = {
        syncOptions = [
          "ServerSideApply=true"
        ]
      }
    }
  }
}

module "monitoring_htpasswd" {
  # source = "git::https://github.com/CloudWebManage/cwm-iac.git//tfmodules/htpasswd?ref=main"
  source = "../../../cwm-iac/tfmodules/htpasswd"
  tools = var.tools
  vault_mount = var.vault_mount
  vault_path = "${var.vault_path}/monitoring/htpasswd"
  vault_kv_put_extra_args = "alertmanager_url=\"https://alertmanager.${var.ingress_star_domain}\" prometheus_url=\"https://prometheus.${var.ingress_star_domain}\""
  secrets = [
    {
      name      = "htpasswd"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
    }
  ]
}

resource "kubernetes_ingress_v1" "monitoring" {
  for_each = {
    alertmanager = {
      auth = true
      serviceName = "monitoring-kube-prometheus-alertmanager"
      port = 9093
    }
    grafana = {
      auth = false
      serviceName = "monitoring-grafana"
      port = 80
    }
    prometheus = {
      auth = true
      serviceName = "monitoring-kube-prometheus-prometheus"
      port = 9090
    }
  }
  metadata {
    name = each.key
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = merge(
      {
        "cert-manager.io/cluster-issuer" : "letsencrypt"
      }, each.value.auth ? {
        "nginx.ingress.kubernetes.io/auth-type": "basic"
        "nginx.ingress.kubernetes.io/auth-secret": "htpasswd"
        "nginx.ingress.kubernetes.io/auth-realm": "Protected Area"
      } : {}
    )
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = ["${each.key}.${var.ingress_star_domain}"]
      secret_name = "${each.key}-tls"
    }
    rule {
      host = "${each.key}.${var.ingress_star_domain}"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = each.value.serviceName
              port {
                number = each.value.port
              }
            }
          }
        }
      }
    }
  }
}
