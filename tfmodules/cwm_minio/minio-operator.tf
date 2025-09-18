module "minio_operator" {
  depends_on = [module.cloudnative_pg, null_resource.directpv_init_drives]
  source = "../../tfmodules/argocd-app"
  name = "minio-operator"
  values = {
    # https://github.com/minio/operator/blob/master/helm/operator/values.yaml
    operator: {
      operator: {
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
