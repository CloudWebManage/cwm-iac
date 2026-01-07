module "minio_operator" {
  depends_on = [module.cloudnative_pg, null_resource.directpv_init_drives]
  source = "../argocd-app"
  name = "minio-operator"
  autosync = true
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
