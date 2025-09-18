resource "null_resource" "minio_tenant_mc_metrics_prometheus_config_vault" {
  depends_on = [module.minio_tenant_main]
  triggers = {
    command = <<-EOT
      ${var.tools.kubectl} exec \
        -n ${kubernetes_namespace.tenant.metadata[0].name} \
        deploy/cwm-minio-api -- mc admin prometheus generate cwm --api-version v3 \
          | ${var.tools.vault} kv put -mount=${var.vault_mount} ${var.vault_path}/mc_metrics_prometheus_config config=-
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}

data "vault_kv_secret_v2" "minio_tenant_main_mc_metrics_prometheus_config" {
  depends_on = [null_resource.minio_tenant_mc_metrics_prometheus_config_vault]
  mount = var.vault_mount
  name = "${var.vault_path}/mc_metrics_prometheus_config"
}

locals {
  cluster_scrape_config = yamldecode(data.vault_kv_secret_v2.minio_tenant_main_mc_metrics_prometheus_config.data.config)["scrape_configs"][0]
}

module "metrics_app" {
  depends_on = [kubernetes_namespace.minio-tenant-metrics]
  source = "../../tfmodules/argocd-app"
  name = "minio-tenant-${var.name}-metrics"
  path = "apps/minio-tenant-metrics"
  values = {
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
                  url = "http://minio-tenant-${var.name}-cwm-api.${kubernetes_namespace.tenant.metadata[0].name}:8000/buckets/list_prometheus_sd?targets=${local.cluster_scrape_config["static_configs"][0]["targets"][0]}"
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
