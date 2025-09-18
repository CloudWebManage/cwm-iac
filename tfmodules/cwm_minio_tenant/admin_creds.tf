resource "random_password" "admin-user" {
  length = 8
}

resource "random_password" "admin-password" {
  length = 16
}

resource "kubernetes_secret" "env-config" {
  depends_on = [kubernetes_namespace.tenant]
  metadata {
    name      = "tenant-env-configuration"
    namespace = "minio-tenant-${var.name}"
  }
  type = "Opaque"
  data = {
    "config.env": <<-EOT
      export MINIO_ROOT_USER=${ random_password.admin-user.result }
      export MINIO_ROOT_PASSWORD=${ random_password.admin-password.result }
    EOT
  }
}

resource "kubernetes_secret" "cwm-minio-api-tenant-creds" {
  metadata {
    name      = "cwm-minio-api-tenant-creds"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }
  type = "Opaque"
  data = {
    url = "https://minio-tenant-${var.name}-api.${var.ingress_star_domain}"
    accesskey = random_password.admin-user.result
    secretkey = random_password.admin-password.result
  }
}
