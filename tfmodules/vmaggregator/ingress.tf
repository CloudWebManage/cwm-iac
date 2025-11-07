module "htpasswd_minio_tenant_main_metrics" {
  source = "../htpasswd"
  tools = var.tools
  vault_mount = var.vault_mount
  vault_path = "${var.vault_path}/htpasswd"
  secrets = [
    {
      name      = "vmaggregator-htpasswd"
      namespace = kubernetes_namespace.vmaggregator.metadata[0].name
    }
  ]
}

resource "kubernetes_ingress_v1" "vmaggregator" {
  metadata {
    name = "vmaggregator"
    namespace = kubernetes_namespace.vmaggregator.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer": "letsencrypt"
      "nginx.ingress.kubernetes.io/auth-type": "basic"
      "nginx.ingress.kubernetes.io/auth-secret": "vmaggregator-htpasswd"
      "nginx.ingress.kubernetes.io/auth-realm": "Protected Area"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = ["vmaggregator.${var.ingress_star_domain}"]
      secret_name = "vmaggregator-tls"
    }
    rule {
      host = "vmaggregator.${var.ingress_star_domain}"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "vmsingle-main"
              port {
                number = 8429
              }
            }
          }
        }
      }
    }
  }
}
