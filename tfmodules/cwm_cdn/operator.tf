locals {
  cdn_operator_kustomization_yaml = <<-EOT
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization

    resources:
    - dist-install-${replace(var.versions["cwm-cdn-operator-dist-install"], "/", "-")}.yaml

    images:
    - name: ghcr.io/cloudwebmanage/cwm-cdn-operator/operator
      newTag: ${var.versions["cwm-cdn-operator"]}

    patches:
      - target:
          kind: Deployment
          name: cwm-cdn-operator-controller-manager
          namespace: cwm-cdn-operator-system
        patch: |-
          - op: replace
            path: /spec/template/spec/containers/0/env
            value:
              - name: CWM_CDN_TENANT_DEFAULT_IMAGE
                value: "ghcr.io/cloudwebmanage/cwm-cdn-api-tenant-nginx:${var.versions["cwm-cdn-api-tenant-nginx"]}"
              - name: CWM_CDN_IS_PRIMARY
                value: "${var.is_primary}"
          - op: replace
            path: /spec/template/spec/containers/0/args
            value:
              - --metrics-bind-address=:8443
              - --leader-elect
              - --health-probe-bind-address=:8081
              - --zap-log-level=${var.cdn_operator_log_level}
  EOT
}

resource "null_resource" "cdn_operator_install" {
  triggers = {
    command = <<-EOT
      set -euo pipefail
      DIST_INSTALL="${var.data_path}/operator/dist-install-${replace(var.versions["cwm-cdn-operator-dist-install"], "/", "-")}.yaml"
      if ! [ -f "$DIST_INSTALL" ]; then
        mkdir -p "${var.data_path}/operator"
        curl -L -o "$DIST_INSTALL" \
          https://raw.githubusercontent.com/CloudWebManage/cwm-cdn-operator/${var.versions["cwm-cdn-operator-dist-install"]}/dist/install.yaml
      fi
      echo '${local.cdn_operator_kustomization_yaml}' > "${var.data_path}/operator/kustomization.yaml"
      KUBECONFIG=${var.kubeconfig_path} ${var.tools.kubectl} apply -k "${var.data_path}/operator"
    EOT
  }
  provisioner "local-exec" {
    command     = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}
