data "external" "download_tools" {
  program = ["bash", "-c", <<-EOT
      set -euo pipefail
      mkdir -p "${var.tools_data_path}"
      filename="${var.tools_data_path}/kubectl-${var.kube_version}"
      if ! [ -f "$filename" ]; then
        curl -L -o "$filename" "https://dl.k8s.io/release/${var.kube_version}/bin/linux/amd64/kubectl"
        chmod +x "$filename"
      fi
      filename="${var.tools_data_path}/kubectl-directpv-${var.directpv_version}"
      if ! [ -f "$filename" ]; then
        curl -L -o "$filename" https://github.com/minio/directpv/releases/download/v${var.directpv_version}/kubectl-directpv_${var.directpv_version}_linux_amd64
        chmod +x "$filename"
      fi
      filename="${var.tools_data_path}/longhornctl-${local.longhorn_version}"
      if ! [ -f "$filename" ]; then
        curl -L -o "$filename" https://github.com/longhorn/cli/releases/download/${local.longhorn_version}/longhornctl-linux-amd64
        chmod +x "$filename"
      fi
      echo '{}'
  EOT
  ]
}

locals {
  kubectl = "KUBECONFIG=${var.kubeconfig_path} ${var.tools_data_path}/kubectl-${var.kube_version}"
  kubectl_directpv = "KUBECONFIG=${var.kubeconfig_path} ${var.tools_data_path}/kubectl-directpv-${var.directpv_version}"
  longhornctl = "KUBECONFIG=${var.kubeconfig_path} ${var.tools_data_path}/longhornctl-${local.longhorn_version}"
}
