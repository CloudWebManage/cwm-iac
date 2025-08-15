output "local_files_terraform_remote_state" {
  value = merge(
    module.local_files_cwm_minio_api_htpasswd.content,
    module.htpasswd_minio_tenant_main_metrics.content,
  )
}
