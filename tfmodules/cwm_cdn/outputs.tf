output "api_creds" {
  value = {
    url = "https://cwm-cdn-api.${var.name_prefix}.${var.ingress_dns_zone_domain}"
    username = random_password.api-username.result
    password = random_password.api-password.result
  }
  sensitive = true
}
