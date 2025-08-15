resource "kubernetes_namespace" "minio-tenant-main-metrics" {
  metadata {
    name = "minio-tenant-main-metrics"
  }
}

locals {
  minio_tenant_main_metrics_values = {
    prometheus = {
      server = {
        namespaces = [
          kubernetes_namespace.minio-tenant-main.metadata[0].name
        ]
      }
    }
  }
}

resource "kubernetes_manifest" "minio-tenant-main-metrics-app" {
  depends_on = [kubernetes_namespace.minio-tenant-main-metrics]
  manifest = yamldecode(<<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: minio-tenant-main-metrics
      namespace: argocd
    spec:
      destination:
        namespace: minio-tenant-main-metrics
        server: 'https://kubernetes.default.svc'
      project: default
      source:
        repoURL: https://github.com/CloudWebManage/cwm-iac
        targetRevision: main
        path: apps/minio-tenant-metrics
        helm:
          valuesObject: ${jsonencode(local.minio_tenant_main_metrics_values)}
  EOT
  )
}

module "htpasswd_minio_tenant_main_metrics" {
  # source = "git::https://github.com/CloudWebManage/cwm-iac.git//tfmodules/htpasswd?ref=main"
  source = "../../../cwm-iac/tfmodules/htpasswd"
  bootstrap = false  # only for first run you should set it to true
  data_path_htpasswd_filename = "${var.data_path}/minio-tenant-main/metrics-htpasswd"
  htpasswd_remote_state_key = "minio-tenant-main-metrics-htpasswd"
  local_files_terraform_remote_state = var.local_files_terraform_remote_state
  secrets = [
    {
      name      = "minio-tenant-main-metrics-htpasswd"
      namespace = kubernetes_namespace.minio-tenant-main-metrics.metadata[0].name
    }
  ]
}

resource "kubernetes_ingress_v1" "minio-tenant-main-metrics-prometheus" {
  metadata {
    name = "prometheus"
    namespace = kubernetes_namespace.minio-tenant-main-metrics.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer": "letsencrypt"
      "nginx.ingress.kubernetes.io/auth-type": "basic"
      "nginx.ingress.kubernetes.io/auth-secret": "minio-tenant-main-metrics-htpasswd"
      "nginx.ingress.kubernetes.io/auth-realm": "Protected Area"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = ["minio-tenant-main-prometheus.${var.ingress_star_domain}"]
      secret_name = "minio-tenant-main-prometheus-tls"
    }
    rule {
      host = "minio-tenant-main-prometheus.${var.ingress_star_domain}"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "minio-tenant-main-metrics-prometheus-server"
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

output "minio_tenant_main_metrics_creds" {
  value = {
    username = module.htpasswd_minio_tenant_main_metrics.username
    password = module.htpasswd_minio_tenant_main_metrics.password
    prometheus_url = "https://minio-tenant-main-prometheus.${var.ingress_star_domain}"
  }
  sensitive = true
}
