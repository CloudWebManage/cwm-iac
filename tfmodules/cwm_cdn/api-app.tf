module "api_app" {
  source = "../argocd-app"
  name = "cdn-api"
  create_namespace = false
  values = {
    isPrimary = var.is_primary
  }
}

resource "kubernetes_manifest" "cwm_cdn_tenants_config_external_secret" {
  count = var.is_primary ? 1 : 0
  depends_on = [kubernetes_namespace.namespaces]
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind = "ExternalSecret"
    metadata = {
      name      = "cwm-cdn-tenants-config"
      namespace = "cdn-api"
    }
    spec = {
      secretStoreRef = {
        name = "vault"
        kind = "ClusterSecretStore"
      }
      target = {
        template = {
          metadata = {
            annotations = {
              "cdn.cloudwm-cdn.com/config" = "true"
            }
          }
          data = {
            "secondaries.json" = jsonencode({
              for name, config in var.secondaries : name => {
                url = "https://cwm-cdn-api.${config.cluster_name}.${var.zone_domain}"
                user = "{{ .${name}_user }}"
                pass = "{{ .${name}_pass }}"
              }
            })
          }
        }
      }
      data = concat(
        [
          for name, config in var.secondaries: {
            secretKey = "${name}_user"
            remoteRef = {
              key = "cwm-worker-cluster/${config.cluster_name}/cwm_cdn/cwm_cdn_api_creds"
              property = "username"
            }
          }
        ],
        [
          for name, config in var.secondaries: {
            secretKey = "${name}_pass"
            remoteRef = {
              key = "cwm-worker-cluster/${config.cluster_name}/cwm_cdn/cwm_cdn_api_creds"
              property = "password"
            }
          }
        ]
      )
    }
  }
}
