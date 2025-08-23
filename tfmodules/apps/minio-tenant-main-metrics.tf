resource "kubernetes_namespace" "minio-tenant-main-metrics" {
  metadata {
    name = "minio-tenant-main-metrics"
  }
}

resource "null_resource" "minio_tenant_main_mc_metrics_prometheus_config_vault" {
  depends_on = [kubernetes_manifest.minio-tenant-main-app]
  triggers = {
    command = <<-EOT
      ${var.tools.kubectl} exec \
        -n ${kubernetes_namespace.minio-tenant-main.metadata[0].name} \
        deploy/cwm-minio-api -- mc admin prometheus generate cwm --api-version v3 \
          | ${var.tools.vault} kv put -mount=${var.vault_mount} ${local.minio_tenant_main_vault_path}/mc_metrics_prometheus_config config=-
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}

data "vault_kv_secret_v2" "minio_tenant_main_mc_metrics_prometheus_config" {
  depends_on = [null_resource.minio_tenant_main_mc_metrics_prometheus_config_vault]
  mount = var.vault_mount
  name = "${local.minio_tenant_main_vault_path}/mc_metrics_prometheus_config"
}

locals {
  cluster_scrape_config = yamldecode(data.vault_kv_secret_v2.minio_tenant_main_mc_metrics_prometheus_config.data.config)["scrape_configs"][0]
}

locals {
  minio_tenant_main_metrics_values = {
    prometheus = {
      serverFiles = {
        "prometheus.yml" = {
          scrape_configs = [
            local.cluster_scrape_config,
            {
              job_name     = "minio-job-buckets"
              bearer_token = local.cluster_scrape_config["bearer_token"]
              scheme       = "https"
              http_sd_configs = [
                {
                  refresh_interval = "30s"
                  url = "http://cwm-minio-api.${kubernetes_namespace.minio-tenant-main.metadata[0].name}:8000/buckets/list_prometheus_sd?targets=${local.cluster_scrape_config["static_configs"][0]["targets"][0]}"
                }
              ],
              relabel_configs = [
                {
                  source_labels = ["bucket"]
                  target_label = "__metrics_path__"
                  replacement = "/minio/metrics/v3/bucket/api/$1"
                }
              ]
            }
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "minio-tenant-main-metrics-app" {
  depends_on = [kubernetes_namespace.minio-tenant-main-metrics]
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "minio-tenant-main-metrics"
      namespace = "argocd"
    }
    spec = {
      destination = {
        namespace = "minio-tenant-main-metrics"
        server    = "https://kubernetes.default.svc"
      }
      project = "default"
      source = {
        repoURL        = "https://github.com/CloudWebManage/cwm-iac"
        targetRevision = "main"
        path           = "apps/minio-tenant-metrics"
        helm = {
          valuesObject = local.minio_tenant_main_metrics_values
        }
      }
    }
  }
}

module "htpasswd_minio_tenant_main_metrics" {
  # source = "git::https://github.com/CloudWebManage/cwm-iac.git//tfmodules/htpasswd?ref=main"
  source = "../../../cwm-iac/tfmodules/htpasswd"
  tools = var.tools
  vault_mount = var.vault_mount
  vault_path = "${local.minio_tenant_main_vault_path}/metrics_htpasswd"
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
