module "htpasswd_minio_tenant_main_metrics" {
  count = var.metrics ? 1 : 0
  source = "../htpasswd"
  tools = var.tools
  vault_mount = var.vault_mount
  vault_path = "${var.vault_path}/metrics_htpasswd"
  secrets = [
    {
      name      = "minio-tenant-main-metrics-htpasswd"
      namespace = kubernetes_namespace.minio-tenant-metrics[0].metadata[0].name
    }
  ]
}
