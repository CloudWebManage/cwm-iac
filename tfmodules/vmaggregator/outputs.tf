output "vmcreds" {
  value = {
    username = module.htpasswd_minio_tenant_main_metrics.username
    password = module.htpasswd_minio_tenant_main_metrics.password
    url = "https://vmaggregator.${var.ingress_star_domain}/"
  }
  sensitive = true
}
