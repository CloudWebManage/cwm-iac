resource "kubernetes_secret" "cwm_minio_api_tenant_info" {
  metadata {
    name      = "cwm-minio-api-tenant-info"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }
  type = "Opaque"
  data = {
    tenant_info_json = jsonencode({
      api_url = "https://minio-tenant-${var.name}-api.${var.ingress_star_domain}"
      console_url = "https://minio-tenant-${var.name}-console.${var.ingress_star_domain}"
      prometheus_url = "https://minio-tenant-${var.name}-prometheus.${var.ingress_star_domain}"
      bucket_api_url = "https://<BUCKET_NAME>.${var.minio_domain}"
    })
  }
}
