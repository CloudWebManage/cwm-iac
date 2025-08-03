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
  EOT
  )
}
