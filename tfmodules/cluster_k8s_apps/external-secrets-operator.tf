resource "kubernetes_namespace" "external-secrets-operator" {
  metadata {
    name = "external-secrets-operator"
  }
}

data "vault_kv_secret_v2" "vault_external_server" {
  mount = "kvv2"
  name  = "cwm-worker-cluster/cwmc-management/vault_external_server"
}

resource "kubernetes_manifest" "external-secrets-operator-app" {
  manifest = {
    apiVersion : "argoproj.io/v1alpha1"
    kind : "Application"
    metadata : {
      name : "external-secrets-operator"
      namespace : "argocd"
    }
    spec : {
      destination : {
        namespace : "external-secrets-operator"
        server : "https://kubernetes.default.svc"
      }
      project : "default"
      source : {
        repoURL : "https://github.com/CloudWebManage/cwm-iac"
        targetRevision : "main"
        path : "apps/external-secrets-operator"
        helm : {
          valuesObject : {
            vault_server : data.vault_kv_secret_v2.vault_external_server.data.server
          }
        }
      }
      syncPolicy : {
        syncOptions : [
          "ServerSideApply=true"
        ]
      }
    }
  }
}

data "vault_kv_secret_v2" "vault_ca_bundle_b64" {
  mount = "kvv2"
  name  = "cwm-worker-cluster/cwmc-management/vault_ca_bundle_b64"
}

resource "kubernetes_secret" "external-secrets-operator-vault-ca-provider" {
  metadata {
    name      = "vault-ca-provider"
    namespace = kubernetes_namespace.external-secrets-operator.metadata[0].name
  }
  data = {
    "ca" = base64decode(data.vault_kv_secret_v2.vault_ca_bundle_b64.data["ca"])
  }
}

resource "vault_policy" "external-secrets-operator" {
  name   = "${var.name_prefix}-external-secrets-operator"
  policy = <<-EOT
    path "auth/approle/login" {
      capabilities = ["create", "read"]
    }
    path "kvv2/data/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_approle_auth_backend_role" "external-secrets-operator" {
  role_name = "${var.name_prefix}-external-secrets-operator"
  token_policies = [
    vault_policy.external-secrets-operator.name,
  ]
}

resource "vault_approle_auth_backend_role_secret_id" "external-secrets-operator" {
  role_name = vault_approle_auth_backend_role.external-secrets-operator.role_name
}

resource "kubernetes_secret" "external-secrets-operator-vault-app-role" {
  metadata {
    name      = "vault-app-role"
    namespace = kubernetes_namespace.external-secrets-operator.metadata[0].name
  }
  data = {
    "id" = vault_approle_auth_backend_role.external-secrets-operator.role_id
    "secret" = vault_approle_auth_backend_role_secret_id.external-secrets-operator.secret_id
  }
}
