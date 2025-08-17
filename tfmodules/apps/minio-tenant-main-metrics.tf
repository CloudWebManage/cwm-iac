resource "kubernetes_namespace" "minio-tenant-main-metrics" {
  metadata {
    name = "minio-tenant-main-metrics"
  }
}

module "local_data_minio_tenant_main_mc_metrics_token" {
  source = "git::https://github.com/CloudWebManage/cwm-iac.git//tfmodules/localdata?ref=main"
  # source = "../../tfmodules/localdata"
  local_file_path = "${local.minio_tenant_main_data_path}/mc-metrics-token"
  output_content = true
  generate_script = <<-EOT
    ${var.tools.kubectl} exec \
          -n ${kubernetes_namespace.minio-tenant-main.metadata[0].name} \
          deploy/cwm-minio-api -- mc admin prometheus generate cwm --api-version v3 \
            > $FILENAME
  EOT
}

locals {
  minio_tenant_main_metrics_values = {
    prometheus = {
      serverFiles = {
        "prometheus.yml" = yamldecode(module.local_data_minio_tenant_main_mc_metrics_token.content)
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
  source = "git::https://github.com/CloudWebManage/cwm-iac.git//tfmodules/htpasswd?ref=main"
  # source = "../../../cwm-iac/tfmodules/htpasswd"
  data_path_htpasswd_filename = "${local.minio_tenant_main_data_path}/metrics-htpasswd"
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
