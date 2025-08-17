module "localdata_curl_download_tools" {
  for_each = {
    kubectl = {
      version = var.kube_version,
      url = "https://dl.k8s.io/release/${var.kube_version}/bin/linux/amd64/kubectl"
    }
    kubectl_directpv = {
      version = var.directpv_version,
      url = "https://github.com/minio/directpv/releases/download/v${var.directpv_version}/kubectl-directpv_${var.directpv_version}_linux_amd64"
    }
    longhornctl = {
      version = local.longhorn_version,
      url = "https://github.com/longhorn/cli/releases/download/${local.longhorn_version}/longhornctl-linux-amd64"
    }
  }
  # source = "git::https://github.com/CloudWebManage/cwm-iac.git//tfmodules/localdata?ref=main"
  source = "../../tfmodules/localdata"
  output_content = false
  local_file_path = "${var.tools_data_path}/${each.key}-${each.value.version}"
  generate_script = <<-EOT
    curl -L -o "$FILENAME" "${each.value.url}" && chmod +x "$FILENAME"
  EOT
}

locals {
  kubectl = "KUBECONFIG=${var.kubeconfig_path} ${var.tools_data_path}/kubectl-${var.kube_version}"
  kubectl_directpv = "KUBECONFIG=${var.kubeconfig_path} ${var.tools_data_path}/kubectl-directpv-${var.directpv_version}"
  longhornctl = "KUBECONFIG=${var.kubeconfig_path} ${var.tools_data_path}/longhornctl-${local.longhorn_version}"
}

output "tools" {
  value = {
    kubectl = local.kubectl
    kubectl_directpv = local.kubectl_directpv
    longhornctl = local.longhornctl
  }
}
