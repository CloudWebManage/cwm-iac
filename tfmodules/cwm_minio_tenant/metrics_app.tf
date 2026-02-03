resource "null_resource" "minio_tenant_mc_metrics_prometheus_config_vault" {
  count = var.metrics ? 1 : 0
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
  count = var.metrics ? 1 : 0
  depends_on = [null_resource.minio_tenant_mc_metrics_prometheus_config_vault]
  mount = var.vault_mount
  name = "${var.vault_path}/mc_metrics_prometheus_config"
}

locals {
  cluster_scrape_config = var.metrics ? yamldecode(data.vault_kv_secret_v2.minio_tenant_main_mc_metrics_prometheus_config[0].data.config)["scrape_configs"][0] : null
}

module "metrics_app" {
  count = var.metrics ? 1 : 0
  depends_on = [kubernetes_namespace.minio-tenant-metrics]
  source = "../argocd-app"
  name = "minio-tenant-${var.name}-metrics"
  autosync = true
  create_namespace = false
  path = "apps/minio-tenant-metrics"
  targetRevision = var.metrics_app_target_revision
  values = {
    vmagent = {
      remoteWrite = var.vmagentRemoteWriteConfig
      clusterLabel = var.vmagent_cluster_label == "" ? var.cluster_name : var.vmagent_cluster_label
      tenantLabel = var.name
    }
    prometheus = {
      serverFiles = {
        "prometheus.yml" = {
          scrape_configs = [
            local.cluster_scrape_config,
            {
              job_name     = "minio-job-buckets"
              bearer_token = local.cluster_scrape_config["bearer_token"]
              scheme       = "https"
              honor_timestamps = false
              http_sd_configs = [
                {
                  refresh_interval = "30s"
                  url = "http://cwm-minio-api.${kubernetes_namespace.tenant.metadata[0].name}:8000/buckets/list_prometheus_sd?targets=${local.cluster_scrape_config["static_configs"][0]["targets"][0]}"
                }
              ],
              relabel_configs = [
                {
                  source_labels = ["bucket"]
                  target_label = "__metrics_path__"
                  replacement = "/minio/metrics/v3/bucket/api/$1"
                }
              ]
            },
            {
              job_name = "minio-audit-metrics"
              scheme = "http"
              scrape_interval = "15s"
              metrics_path = "/metrics"
              honor_timestamps = false
              kubernetes_sd_configs = [
                {
                  role = "pod"
                  namespaces = {
                    names = [kubernetes_namespace.tenant.metadata[0].name]
                  }
                }
              ]
              relabel_configs = [
                {
                  source_labels = ["__meta_kubernetes_pod_label_cwm_minio_tenant"]
                  regex = "true"
                  action = "keep"
                },
                {
                  source_labels = ["__meta_kubernetes_pod_ip"]
                  target_label = "__address__"
                  replacement = "$1:8799"
                }
              ]
            },
            {
              job_name = "cwm-minio-api"
              scheme = "http"
              scrape_interval = "15s"
              metrics_path = "/metrics"
              honor_timestamps = false
              kubernetes_sd_configs = [
                {
                  role = "pod"
                  namespaces = {
                    names = [kubernetes_namespace.tenant.metadata[0].name]
                  }
                }
              ]
              relabel_configs = [
                {
                  source_labels = ["__meta_kubernetes_pod_label_app"]
                  regex = "cwm-minio-api"
                  action = "keep"
                },
                {
                  source_labels = ["__meta_kubernetes_pod_ip"]
                  target_label = "__address__"
                  replacement = "$1:8000"
                }
              ]
            }
          ]
        }
      }
    }
  }
}
