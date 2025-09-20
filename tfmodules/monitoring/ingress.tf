module "monitoring_htpasswd" {
  source = "../htpasswd"
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
