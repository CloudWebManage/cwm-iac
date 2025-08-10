resource "kubernetes_namespace" "cloudnative-pg" {
  metadata {
    name = "cloudnative-pg"
  }
}

resource "kubernetes_manifest" "cloudnative-pg-app" {
  depends_on = [kubernetes_namespace.cloudnative-pg]
  manifest = yamldecode(<<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: cloudnative-pg
      namespace: argocd
    spec:
      destination:
        namespace: cloudnative-pg
        server: 'https://kubernetes.default.svc'
      project: default
      source:
        repoURL: https://github.com/CloudWebManage/cwm-iac
        targetRevision: main
        path: apps/cloudnative-pg
  EOT
  )
}
