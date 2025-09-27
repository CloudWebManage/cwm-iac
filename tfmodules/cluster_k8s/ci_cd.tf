resource "kubernetes_service_account" "github_actions" {
  metadata {
    name      = "github-actions"
    namespace = "kube-system"
  }
}

resource "kubernetes_role" "github_actions_argocd" {
  metadata {
    name      = "github-actions"
    namespace = "argocd"
  }
  rule {
    api_groups = ["argoproj.io"]
    resources  = ["applications"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }
}

resource "kubernetes_role_binding" "github_actions_argocd" {
  metadata {
    name      = "github-actions-argocd"
    namespace = "argocd"
  }
  role_ref {
    kind      = "Role"
    name      = kubernetes_role.github_actions_argocd.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.github_actions.metadata[0].name
    namespace = kubernetes_service_account.github_actions.metadata[0].namespace
  }
}
