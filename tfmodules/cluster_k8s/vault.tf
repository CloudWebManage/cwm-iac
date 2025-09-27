resource "kubernetes_service_account" "vault_k8s_issuer" {
  metadata {
    name      = "vault-k8s-issuer"
    namespace = "kube-system"
  }
}

resource "kubernetes_role" "vault_k8s_issuer" {
  metadata {
    name      = "vault-k8s-issuer"
    namespace = "kube-system"
  }
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts/token"]
    verbs      = ["create"]
    resource_names = [
      kubernetes_service_account.github_actions.metadata[0].name
    ]
  }
}

resource "kubernetes_role_binding" "vault_k8s_issuer" {
  metadata {
    name      = "vault-k8s-issuer"
    namespace = "kube-system"
  }
  role_ref {
    kind      = "Role"
    name      = kubernetes_role.vault_k8s_issuer.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_k8s_issuer.metadata[0].name
    namespace = kubernetes_service_account.vault_k8s_issuer.metadata[0].namespace
  }
}

resource "kubernetes_secret" "vault_k8s_issuer" {
  metadata {
    name      = "vault-k8s-issuer"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.vault_k8s_issuer.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}
