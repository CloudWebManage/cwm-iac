resource "random_password" "tenant-admin-user" {
  length = 8
  special = false
}

resource "random_password" "tenant-admin-password" {
  length = 16
  special = false
}

resource "kubernetes_secret" "tenant-env-config" {
  depends_on = [kubernetes_namespace.logging]
  metadata {
    name      = "tenant-env-configuration"
    namespace = "logging"
  }
  type = "Opaque"
  data = {
    "config.env": <<-EOT
      export MINIO_ROOT_USER=${ random_password.tenant-admin-user.result }
      export MINIO_ROOT_PASSWORD=${ random_password.tenant-admin-password.result }
    EOT
  }
}
