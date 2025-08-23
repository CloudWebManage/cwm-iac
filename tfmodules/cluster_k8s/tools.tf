locals {
  kubectl = "KUBECONFIG=${var.kubeconfig_path} ${var.tools.kubectl}"
  kubectl_directpv = "KUBECONFIG=${var.kubeconfig_path} ${var.tools.kubectl_directpv}"
}
