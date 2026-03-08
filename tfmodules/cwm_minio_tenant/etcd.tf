module "etcd" {
  source = "../argocd-app"
  name = "minio-${var.name}-etcd"
  path = "apps/etcd"
  namespace = kubernetes_namespace.tenant.metadata[0].name
  create_namespace = false
  versions = var.versions
  targetRevisionFromVersionByName = true
  autosync = var.argocd_autosync
  values = {
    etcd = {
      tolerations = [
        for val in (var.etcd_use_systemlogging_role ? ["system", "logging"] : ["system"]) :
        {
          key = "cwm-iac-worker-role"
          operator = "Equal"
          value = val
          effect = "NoExecute"
        }
      ]
    }
  }
}
