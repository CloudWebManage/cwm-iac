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
    counter = lookup(var.force_reinstall_counters, "directpv", 0)
    command = <<-EOT
      set -euo pipefail
      mkdir -p "${var.data_path}/directpv"
      ${local.kubectl_directpv} install \
        --tolerations cwm-iac-worker-role=minio:NoExecute \
        -o yaml > "${var.data_path}/directpv/install.yaml"
      echo '${local.directpv_kustomization_yaml}' > "${var.data_path}/directpv/kustomization.yaml"
      ${local.kubectl} apply -k "${var.data_path}/directpv"
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}

resource "null_resource" "directpv_init_drives" {
  triggers = {
    counter = lookup(var.force_reinstall_counters, "directpv_init_drives", 0)
    command = <<-EOT
      set -euo pipefail
      ${local.kubectl_directpv} discover --output-file "${var.data_path}/directpv/drives.yaml"
      ${local.kubectl_directpv} init "${var.data_path}/directpv/drives.yaml" --dangerous
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}
