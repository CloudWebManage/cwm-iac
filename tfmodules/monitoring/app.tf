module "app" {
  source = "../argocd-app"
  name = "monitoring"
  create_namespace = false
  versions = var.versions
  targetRevisionFromVersionByName = true
  values = {
    "kube-prometheus-stack" = {
      alertmanager = {
        alertmanagerSpec = {
          externalUrl = "https://alertmanager.${var.ingress_star_domain}"
        }
        config = {
          route = {
            receiver = "slack"
            routes = [
              {
                matchers = ["alertname = \"Watchdog\""]
                receiver = "slack_watchdog"
                repeat_interval = "1h"
              }
            ]
          }
          receivers = [
            {
              name = "slack"
              slack_configs = [
                {
                  api_url = var.slack_alerts_webhook_url
                  channel = "#cwm-alerts"
                  send_resolved = true
                  text = <<-EOT
                    ${var.cluster_name}
                    {{ len .Alerts }} alerts for namespace "{{ .CommonLabels.namespace }}"
                    {{ range $i, $alert := .Alerts }}
                    *Alert #{{$i}}* | {{ .Labels.alertname }} | {{ .Status }} | {{ .StartsAt }}
                    {{ range $k, $v := .Labels }}  - {{$k}}: {{$v}}
                    {{ end }}{{ range $k, $v := .Annotations }}  - {{$k}}: {{$v}}
                    {{ end }}<{{ .GeneratorURL }}|View in Prometheus>
                    {{ end }}
                  EOT
                }
              ]
            },
            {
              name = "slack_watchdog"
              slack_configs = [
                {
                  api_url = var.slack_alerts_watchdog_webhook_url
                  channel = "#cloudwm-watchdog"
                  send_resolved = false
                  text = var.cluster_name
                }
              ]
            }
          ]
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
    automated = {
      prune = true
      selfHeal = true
    }
    syncOptions = [
      "ServerSideApply=true"
    ]
  }
}
