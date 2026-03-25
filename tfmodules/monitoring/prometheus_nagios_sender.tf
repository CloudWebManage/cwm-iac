resource "kubernetes_secret" "prometheus_nagios_sender_etc" {
  metadata {
    name = "prometheus-nagios-sender-etc"
    namespace = "monitoring"
  }
  data = {
    "send_nsca.cfg" = var.send_nsca_cfg
    "config.yaml" = var.prometheus_nagios_sender_config_yaml
  }
}

resource "kubernetes_secret" "prometheus_nagios_sender_env" {
  metadata {
    name = "prometheus-nagios-sender-env"
    namespace = "monitoring"
  }
  data = {
    PROM_API_URL = "http://${module.monitoring_htpasswd.username}:${module.monitoring_htpasswd.password}@monitoring-kube-prometheus-prometheus:9090/api"
    SEND_NSCA_HOST = var.send_nsca_host
  }
}
