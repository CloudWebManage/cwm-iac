resource "random_password" "cwm-postgres-superuser-password" {
  length = 16
}

resource "kubernetes_secret" "cwm-postgres-superuser" {
  metadata {
    name      = "cwm-postgres-superuser"
    namespace = kubernetes_namespace.tenant.metadata[0].name
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
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }
  type = "Opaque"
  data = {
    DB_CONNSTRING = "postgresql://postgres:${urlencode(random_password.cwm-postgres-superuser-password.result)}@cwm-rw/postgres"
  }
}
