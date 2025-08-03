resource "null_resource" "download_tools" {
  triggers = {
    counter = lookup(var.force_reinstall_counters, "download_tools", 0)
    command = <<-EOT
      set -euo pipefail
      KUBE_VERSION="${var.kube_version}"
      DATA_PATH="${var.tools_data_path}"
      mkdir -p "$DATA_PATH"
      if ! [ -f "$DATA_PATH/kubectl-$KUBE_VERSION" ]; then
        curl -L -o "$DATA_PATH/kubectl-$KUBE_VERSION" "https://dl.k8s.io/release/$KUBE_VERSION/bin/linux/amd64/kubectl"
        chmod +x "$DATA_PATH/kubectl-$KUBE_VERSION"
      fi
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}

locals {
  kubectl = "KUBECONFIG=${var.kubeconfig_path} ${var.tools_data_path}/kubectl-${var.kube_version}"
}
