output "outputs" {
  value = {
    grafana = {
      url = "https://grafana.${var.ingress_star_domain}"
      user = random_password.monitoring_grafana_admin_user.result
      password = random_password.monitoring_grafana_admin_password.result
    }
    prometheus = {
      url = "https://prometheus.${var.ingress_star_domain}"
      user = module.monitoring_htpasswd.username
      password = module.monitoring_htpasswd.password
    }
    alertmanager = {
      url = "https://alertmanager.${var.ingress_star_domain}"
      user = module.monitoring_htpasswd.username
      password = module.monitoring_htpasswd.password
    }
  }
  sensitive = true
}
