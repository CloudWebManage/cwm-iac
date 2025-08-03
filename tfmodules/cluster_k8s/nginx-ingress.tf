resource "kubernetes_manifest" "nginx-ingress-helm-chart-config" {
  manifest = {
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "rke2-ingress-nginx"
      namespace = "kube-system"
    }
    spec = {
      valuesContent = <<-EOT
        controller:
          config:
            # this is required for cert-manager, see https://cert-manager.io/docs/releases/release-notes/release-notes-1.18/
            strict-validate-path-type: false
      EOT
    }
  }
}
