resource "aws_route53_record" "subdomain_star" {
  provider = aws.route53
  zone_id = var.zone_id
  name    = "*.${var.minio_domain}"
  type    = "CNAME"
  ttl     = 300
  records = ["ingress.${var.ingress_star_domain}"]
}

resource "aws_route53_record" "subdomain" {
  provider = aws.route53
  zone_id = var.zone_id
  name    = var.minio_domain
  type    = "CNAME"
  ttl     = 300
  records = ["ingress.${var.ingress_star_domain}"]
}

resource "kubernetes_ingress_v1" "subdomain_star" {
  depends_on = [kubernetes_namespace.tenant]
  metadata {
    name = "subdomain-star"
    namespace = kubernetes_namespace.tenant.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer": "letsencrypt"
      "nginx.ingress.kubernetes.io/proxy-body-size" = "5g"
      "nginx.ingress.kubernetes.io/service-upstream" = "true"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = ["*.${var.minio_domain}"]
      secret_name = "subdomain-star-tls"
    }
    rule {
      host = "*.${var.minio_domain}"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.node_local_enabled ? "minio-tenant-node-local" : "minio"
              port {
                name = "http-minio"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "subdomain" {
  depends_on = [kubernetes_namespace.tenant]
  metadata {
    name = "subdomain"
    namespace = kubernetes_namespace.tenant.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer": "letsencrypt"
      "nginx.ingress.kubernetes.io/proxy-body-size" = "5g"
      "nginx.ingress.kubernetes.io/service-upstream" = "true"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = [var.minio_domain]
      secret_name = "subdomain-tls"
    }
    rule {
      host = var.minio_domain
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.node_local_enabled ? "minio-tenant-node-local" : "minio"
              port {
                name = "http-minio"
              }
            }
          }
        }
      }
    }
  }
}
