module "app" {
  source = "../../tfmodules/argocd-app"
  name = "monitoring"
  create_namespace = false
  values = {
    "kube-prometheus-stack" = {
      alertmanager = {
        alertmanagerSpec = {
          externalUrl = "https://alertmanager.${var.ingress_star_domain}"
        }
      }
      prometheus = {
        prometheusSpec = {
          externalUrl = "https://prometheus.${var.ingress_star_domain}"
        }
      }
    }
  }
  sync_policy = {
    syncOptions = [
      "ServerSideApply=true"
    ]
  }
}
