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
      export MINIO_STORAGE_CLASS_STANDARD="${var.erasure_code_standard}"
      export MINIO_STORAGE_CLASS_RRS="${var.erasure_code_reduced}"
      export MINIO_DOMAIN="${var.minio_domain}"
      export MINIO_AUDIT_QUEUE_DIR="/export/audit-queue"
      export MINIO_AUDIT_QUEUE_DIR_MAX_SIZE="1000000"
    EOT
  }
}
