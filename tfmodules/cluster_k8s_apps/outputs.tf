output "outputs" {
  value = {
    longhorn_creds = {
      url = "https://longhorn.${var.ingress_star_domain}"
      user = module.longhorn_htpasswd.username
      password = module.longhorn_htpasswd.password
    }
  }
  sensitive = true
}
