output "local_files_terraform_remote_state" {
  value = merge(
    module.local_files_cwm_minio_api_htpasswd.content
  )
}
