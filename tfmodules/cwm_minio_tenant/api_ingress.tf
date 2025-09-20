resource "kubernetes_ingress_v1" "cwm-minio-api" {
  count = var.initialize ? 0 : 1
  depends_on = [kubernetes_namespace.tenant]
  metadata {
    name = "cwm-minio-api"
    namespace = kubernetes_namespace.tenant.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer": "letsencrypt"
      "nginx.ingress.kubernetes.io/auth-type": "basic"
      "nginx.ingress.kubernetes.io/auth-secret": "cwm-minio-api-htpasswd"
      "nginx.ingress.kubernetes.io/auth-realm": "Protected Area"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = ["minio-tenant-${var.name}-cwm-api.${var.ingress_star_domain}"]
      secret_name = "cwm-minio-api-tls"
    }
    rule {
      host = "minio-tenant-${var.name}-cwm-api.${var.ingress_star_domain}"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "cwm-minio-api"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }
}
