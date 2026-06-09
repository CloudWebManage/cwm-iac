resource "kubernetes_manifest" "tenant-certs" {
  field_manager {
    force_conflicts = true
  }
  manifest = yamldecode(<<-EOT
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cdn-tenant-certs
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${var.tenant_certs_letsencrypt_email}
    privateKeySecretRef:
      name: cdn-tenant-certs-issuer-private-key
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            spec:
              tolerations:
              - key: cwm-iac-worker-role
                operator: Equal
                value: system
                effect: NoExecute
EOT
  )
}
