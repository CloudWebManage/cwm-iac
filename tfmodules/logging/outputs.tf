output "outputs" {
  value = {
    minio = {
      api_url = "https://logging-minio-tenant-api.${var.ingress_star_domain}"
      console_url = "https://logging-minio-tenant-console.${var.ingress_star_domain}"
      admin_access_key = random_password.tenant-admin-user.result
      admin_secret_key = random_password.tenant-admin-password.result
    }
  }
  sensitive = true
}
