locals {
  directpv_kustomization_yaml = <<-EOT
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization

    resources:
    - install.yaml

    patches:
    - target:
        kind: Deployment
        name: controller
      patch: |
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: controller
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

resource "null_resource" "directpv_install" {
  triggers = {
    command = <<-EOT
      set -euo pipefail
      mkdir -p "${var.data_path}/directpv"
      export KUBECONFIG=${var.kubeconfig_path}
      ${var.tools.kubectl_directpv} install \
        --tolerations cwm-iac-worker-role=minio:NoExecute,cwm-iac-worker-role=logging:NoExecute \
        -o yaml > "${var.data_path}/directpv/install.yaml"
      echo '${local.directpv_kustomization_yaml}' > "${var.data_path}/directpv/kustomization.yaml"
      ${var.tools.kubectl} apply -k "${var.data_path}/directpv"
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}

data "external" "directpv_discover" {
  program = [
    "bash", "-c", <<-EOT
      set -euo pipefail
      OLD_DRIVES_HASH=""
      if [ -f "${var.data_path}/directpv/drives.yaml" ]; then
        OLD_DRIVES_HASH="$(sha256sum ${var.data_path}/directpv/drives.yaml | cut -d' ' -f1)"
      fi
      export KUBECONFIG=${var.kubeconfig_path}
      if ${var.tools.kubectl_directpv} discover --quiet --output-file "${var.data_path}/directpv/drives.yaml" >/dev/null; then
        echo '{"drives_hash": "'$(sha256sum ${var.data_path}/directpv/drives.yaml | cut -d' ' -f1)'"}'
      else
        echo '{"drives_hash": "'$OLD_DRIVES_HASH'"}'
      fi
    EOT
  ]
}

resource "null_resource" "directpv_init_drives" {
  triggers = {
    drives_hash = data.external.directpv_discover.result.drives_hash
    command = <<-EOT
      set -euo pipefail
      if [ -f "${var.data_path}/directpv/drives.yaml" ]; then
        KUBECONFIG=${var.kubeconfig_path} ${var.tools.kubectl_directpv} init "${var.data_path}/directpv/drives.yaml" --dangerous
      fi
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}
