output "minio_tenant" {
  value = {
    api_url = "https://minio-tenant-main-api.${var.ingress_star_domain}"
    console_url = "https://minio-tenant-main-console.${var.ingress_star_domain}"
    admin_username = random_password.admin-user.result
    admin_password = random_password.admin-password.result
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
    username = module.htpasswd_minio_tenant_main_metrics.username
    password = module.htpasswd_minio_tenant_main_metrics.password
    prometheus_url = "https://minio-tenant-main-prometheus.${var.ingress_star_domain}"
  }
  sensitive = true
}
