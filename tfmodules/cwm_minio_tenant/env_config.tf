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
      export MINIO_AUDIT_WEBHOOK_QUEUE_DIR_METRICS="/export/audit-queue/metrics"
      export MINIO_AUDIT_WEBHOOK_QUEUE_SIZE_METRICS="1000000"
      export MINIO_AUDIT_WEBHOOK_ENABLE_METRICS="on"
      export MINIO_AUDIT_WEBHOOK_ENDPOINT_METRICS="http://localhost:8791"
      export MINIO_ETCD_ENDPOINTS=http://minio-main-etcd.minio-tenant-main:2379
      export MINIO_ETCD_PATH_PREFIX=/minio-tenant-${var.name}
      export MINIO_PUBLIC_IPS=localhost
    EOT
  }
}
