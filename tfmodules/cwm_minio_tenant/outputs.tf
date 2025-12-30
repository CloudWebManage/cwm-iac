output "minio_tenant" {
  value = {
    api_url = "https://minio-tenant-${var.name}-api.${var.ingress_star_domain}"
    console_url = "https://minio-tenant-${var.name}-console.${var.ingress_star_domain}"
    admin_username = random_password.admin-user.result
    admin_password = random_password.admin-password.result
    api_bucket_url = "https://<BUCKET_NAME>.${var.minio_domain}"
  }
  sensitive = true
}

output "cwm_minio_api" {
  value = {
    api_url = "https://minio-tenant-${var.name}-cwm-api.${var.ingress_star_domain}"
    username = random_password.api-username.result
    password = random_password.api-password.result
  }
  sensitive = true
}

output "minio_tenant_metrics_creds" {
  value = {
    username = var.metrics ? module.htpasswd_minio_tenant_main_metrics[0].username : ""
    password = var.metrics ? module.htpasswd_minio_tenant_main_metrics[0].password : ""
    prometheus_url = "https://minio-tenant-${var.name}-prometheus.${var.ingress_star_domain}"
  }
  sensitive = true
}
