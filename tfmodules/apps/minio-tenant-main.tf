locals {
  minio_tenant_main_data_path = "${var.data_path}/minio-tenant-main"
}

resource "kubernetes_namespace" "minio-tenant-main" {
  metadata {
    name = "minio-tenant-main"
  }
}

resource "random_password" "minio-tenant-main-root-user" {
  length = 8
}

resource "random_password" "minio-tenant-main-root-password" {
  length = 16
}

resource "kubernetes_secret" "minio-tenant-main-env-config" {
  metadata {
    name      = "tenant-env-configuration"
    namespace = kubernetes_namespace.minio-tenant-main.metadata[0].name
  }
  type = "Opaque"
  data = {
    "config.env": <<-EOT
      export MINIO_ROOT_USER=${ random_password.minio-tenant-main-root-user.result }
      export MINIO_ROOT_PASSWORD=${ random_password.minio-tenant-main-root-password.result }
    EOT
  }
}

resource "kubernetes_secret" "cwm-minio-api-tenant-creds" {
  metadata {
    name      = "cwm-minio-api-tenant-creds"
    namespace = kubernetes_namespace.minio-tenant-main.metadata[0].name
  }
  type = "Opaque"
  data = {
    url = "https://minio-tenant-main-api.${var.ingress_star_domain}"
    accesskey = random_password.minio-tenant-main-root-user.result
    secretkey = random_password.minio-tenant-main-root-password.result
  }
}

resource "random_password" "cwm-postgres-superuser-password" {
  length = 16
}

resource "kubernetes_secret" "cwm-postgres-superuser" {
  metadata {
    name      = "cwm-postgres-superuser"
    namespace = kubernetes_namespace.minio-tenant-main.metadata[0].name
  }
  type = "Opaque"
  data = {
    username = "postgres"
    password = random_password.cwm-postgres-superuser-password.result
  }
}

resource "kubernetes_secret" "cwm-minio-api-db" {
  metadata {
    name      = "cwm-minio-api-db"
    namespace = kubernetes_namespace.minio-tenant-main.metadata[0].name
  }
  type = "Opaque"
  data = {
    DB_CONNSTRING = "postgresql://postgres:${urlencode(random_password.cwm-postgres-superuser-password.result)}@cwm-rw/postgres"
  }
}

locals {
  minio_tenant_main_values = {
    tenant = {
      ingress = {
        api = {
          enabled = true
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt"
          }
          host = "minio-tenant-main-api.${var.ingress_star_domain}"
          tls = [
            {
              hosts = ["minio-tenant-main-api.${var.ingress_star_domain}"]
              secretName = "minio-tenant-main-api-tls"
            }
          ]
        }
        console = {
          enabled = true
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt"
          }
          host = "minio-tenant-main-console.${var.ingress_star_domain}"
          tls = [
            {
              hosts = ["minio-tenant-main-console.${var.ingress_star_domain}"]
              secretName = "minio-tenant-main-console-tls"
            }
          ]
        }
      }
      tenant = {
        name = "main"
        image = {
          tag = "RELEASE.2025-07-23T15-54-02Z"
        }
        configSecret = {
          name = kubernetes_secret.minio-tenant-main-env-config.metadata[0].name
          existingSecret = true
        }
        certificate = {
          requestAutoCert = false
        }
        pools = [
          {
            name = "pool-1"
            servers = 1
            volumesPerServer = 1
            volumeSize = "999Gi"
            storageClassName = "directpv-min-io"
            labels = {
              "cwm-minio-tenant" = "true"
            }
            tolerations = [
              {
                key = "cwm-iac-worker-role"
                operator = "Equal"
                value = "minio"
                effect = "NoExecute"
              }
            ]
          }
        ]
      }
    }
  }
}

resource "kubernetes_manifest" "minio-tenant-main-app" {
  manifest = yamldecode(<<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: minio-tenant-main
      namespace: argocd
    spec:
      destination:
        namespace: minio-tenant-main
        server: 'https://kubernetes.default.svc'
      project: default
      source:
        repoURL: https://github.com/CloudWebManage/cwm-iac
        targetRevision: main
        path: apps/minio-tenant
        helm:
          valuesObject: ${jsonencode(local.minio_tenant_main_values)}
  EOT
  )
}

resource "random_password" "cwm-minio-api-username" {
  length = 8
  special = false
}
resource "random_password" "cwm-minio-api-password" {
  length = 24
  special = false
}

module "localdata_cwm_minio_api_htpasswd" {
  depends_on = [random_password.cwm-minio-api-username, random_password.cwm-minio-api-password]
  source = "git::https://github.com/CloudWebManage/cwm-iac.git//tfmodules/localdata?ref=main"
  # source = "../../../cwm-iac/tfmodules/localdata"
  local_file_path = "${local.minio_tenant_main_data_path}/cwm-minio-api-htpasswd"
  generate_script = <<-EOT
    htpasswd -bn "${random_password.cwm-minio-api-username.result}" "${random_password.cwm-minio-api-password.result}" \
      > "$FILENAME"
  EOT
}

resource "kubernetes_secret" "cwm-minio-api-htpasswd" {
  metadata {
    name      = "cwm-minio-api-htpasswd"
    namespace = kubernetes_namespace.minio-tenant-main.metadata[0].name
  }
  type = "Opaque"
  data = {
    auth = module.localdata_cwm_minio_api_htpasswd.content
  }
}

resource "kubernetes_ingress_v1" "cwm-minio-api" {
  metadata {
    name = "cwm-minio-api"
    namespace = kubernetes_namespace.minio-tenant-main.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer": "letsencrypt"
      "nginx.ingress.kubernetes.io/auth-type": "basic"
      "nginx.ingress.kubernetes.io/auth-secret": "cwm-minio-api-htpasswd"
      "nginx.ingress.kubernetes.io/auth-realm": "Protected Area"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = ["cwm-minio-api.${var.ingress_star_domain}"]
      secret_name = "cwm-minio-api-tls"
    }
    rule {
      host = "cwm-minio-api.${var.ingress_star_domain}"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "cwm-minio-api"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_secret" "cwm_minio_api_tenant_info" {
  metadata {
    name      = "cwm-minio-api-tenant-info"
    namespace = kubernetes_namespace.minio-tenant-main.metadata[0].name
  }
  type = "Opaque"
  data = {
    tenant_info_json = jsonencode({
      api_url = "https://minio-tenant-main-api.${var.ingress_star_domain}"
      console_url = "https://minio-tenant-main-console.${var.ingress_star_domain}"
    })
  }
}

output "minio_tenant_main" {
  value = {
    api_url = "https://minio-tenant-main-api.${var.ingress_star_domain}"
    console_url = "https://minio-tenant-main-console.${var.ingress_star_domain}"
    admin_username = random_password.minio-tenant-main-root-user.result
    admin_password = random_password.minio-tenant-main-root-password.result
  }
  sensitive = true
}

output "cwm_minio_api" {
  value = {
    api_url = "https://cwm-minio-api.${var.ingress_star_domain}"
    username = random_password.cwm-minio-api-username.result
    password = random_password.cwm-minio-api-password.result
  }
  sensitive = true
}
