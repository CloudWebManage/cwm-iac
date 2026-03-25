module "minio_operator" {
  depends_on = [module.cloudnative_pg]
  source = "../argocd-app"
  name = "minio-operator"
  autosync = var.argocd_autosync
  versions = var.versions
  targetRevisionFromVersionByName = true
  tools = var.tools
  kubeconfig_path = var.kubeconfig_path
  values = {
    # https://github.com/minio/operator/blob/master/helm/operator/values.yaml
    operator: {
      operator: {
        replicaCount: 1
        tolerations: [
          {
            key: "cwm-iac-worker-role"
            operator: "Equal"
            value: "system"
            effect: "NoExecute"
          }
        ]
      }
    }
  }
}
