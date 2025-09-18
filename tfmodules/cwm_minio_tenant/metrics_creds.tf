module "htpasswd_minio_tenant_main_metrics" {
  # source = "git::https://github.com/CloudWebManage/cwm-iac.git//tfmodules/htpasswd?ref=main"
  source = "../htpasswd"
  tools = var.tools
  vault_mount = var.vault_mount
  vault_path = "${var.vault_path}/metrics_htpasswd"
  secrets = [
    {
      name      = "minio-tenant-main-metrics-htpasswd"
      namespace = kubernetes_namespace.minio-tenant-metrics.metadata[0].name
    }
  ]
}
