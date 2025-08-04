locals {
  minio_operator_values = {
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

resource "kubernetes_manifest" "minio-operator-app" {
  manifest = yamldecode(<<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: minio-operator
      namespace: argocd
    spec:
      destination:
        namespace: minio-operator
        server: 'https://kubernetes.default.svc'
      project: default
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
      source:
        repoURL: https://github.com/CloudWebManage/cwm-iac
        targetRevision: main
        path: apps/minio-operator
        helm:
          valuesObject: ${jsonencode(local.minio_operator_values)}
  EOT
  )
}
