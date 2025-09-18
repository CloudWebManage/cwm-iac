resource "kubernetes_ingress_v1" "minio-tenant-metrics-prometheus" {
  metadata {
    name = "prometheus"
    namespace = kubernetes_namespace.minio-tenant-metrics.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer": "letsencrypt"
      "nginx.ingress.kubernetes.io/auth-type": "basic"
      "nginx.ingress.kubernetes.io/auth-secret": "minio-tenant-${var.name}-metrics-htpasswd"
      "nginx.ingress.kubernetes.io/auth-realm": "Protected Area"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = ["minio-tenant-${var.name}-prometheus.${var.ingress_star_domain}"]
      secret_name = "minio-tenant-${var.name}-prometheus-tls"
    }
    rule {
      host = "minio-tenant-${var.name}-prometheus.${var.ingress_star_domain}"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "minio-tenant-${var.name}-metrics-prometheus-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
