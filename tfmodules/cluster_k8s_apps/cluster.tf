module "cluster-app" {
  source = "../argocd-app"
  name = "cluster"
  namespace = "default"
  create_namespace = false
  autosync = true
}

# this key is used by github actions to sync argocd apps
resource "terraform_data" "argocd_syncer_token" {
  triggers_replace = [
    <<-EOT
      set -euo pipefail
      TMPFILE=$(mktemp)
      trap 'rm -f "$TMPFILE"' EXIT
      ARGOCD_PASSWORD="$(KUBECONFIG=${var.admin_kubeconfig_path} ${var.tools["kubectl"]} -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode)"
      ${var.tools["argocd"]} login argocd.${var.ingress_star_domain} --username admin --password "$ARGOCD_PASSWORD" --grpc-web --config $TMPFILE
      TOKEN="$(${var.tools["argocd"]} proj role create-token default syncer --token-only --config $TMPFILE)"
      ${var.tools.vault} kv put -mount=${var.vault_mount} ${var.vault_path}/argocd_syncer_token token="$TOKEN"
    EOT
  ]
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = self.triggers_replace[0]
  }
}
