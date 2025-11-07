locals {
  victoria_metrics_operator_kustomization_yaml = <<-EOT
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization

    resources:
    - install-${var.versions["victoria_metrics_operator"]}.yaml

    patches:
    - target:
        kind: Deployment
        name: vm-operator
      patch: |
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: vm-operator
        spec:
          template:
            spec:
              tolerations:
              - key: "cwm-iac-worker-role"
                operator: "Equal"
                value: "system"
                effect: "NoExecute"
  EOT
}


resource "terraform_data" "install_victoria_metrics_operator" {
  triggers_replace = [
    <<-EOT
      set -euo pipefail
      DATA_PATH="${var.data_path}/victoria_metrics_operator"
      VERSION="${var.versions["victoria_metrics_operator"]}"
      INSTALL_PATH="$DATA_PATH/install-$VERSION.yaml"
      mkdir -p "$DATA_PATH"
      if ! [ -f "$INSTALL_PATH" ]; then
        curl -L -o "$INSTALL_PATH" \
          "https://github.com/VictoriaMetrics/operator/releases/download/$VERSION/install-no-webhook.yaml"
      fi
      echo "${local.victoria_metrics_operator_kustomization_yaml}" > "$DATA_PATH/kustomization.yaml"
      KUBECONFIG=${var.admin_kubeconfig_path} ${var.tools.kubectl} apply -k "$DATA_PATH"
    EOT
  ]
  provisioner "local-exec" {
    command = self.triggers_replace[0]
    interpreter = ["bash", "-c"]
  }
}
