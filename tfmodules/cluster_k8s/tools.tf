locals {
  kubectl = "KUBECONFIG=${var.kubeconfig_path} ${var.tools.kubectl}"
}
