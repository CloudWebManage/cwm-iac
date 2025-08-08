resource "kubernetes_manifest" "rke2-coredns-helm-chart-config" {
  field_manager {
    force_conflicts = true
  }
  manifest = {
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "rke2-coredns"
      namespace = "kube-system"
    }
    spec = {
      valuesContent = <<-EOT
        tolerations:
          - key: "cwm-iac-worker-role"
            operator: "Equal"
            value: "system"
            effect: "NoExecute"
        autoscaler:
          tolerations:
          - key: "cwm-iac-worker-role"
            operator: "Equal"
            value: "system"
            effect: "NoExecute"
      EOT
    }
  }
}

resource "kubernetes_manifest" "rke2-metrics-server-helm-chart-config" {
  field_manager {
    force_conflicts = true
  }
  manifest = {
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "rke2-metrics-server"
      namespace = "kube-system"
    }
    spec = {
      valuesContent = <<-EOT
        tolerations:
          - key: "cwm-iac-worker-role"
            operator: "Equal"
            value: "system"
            effect: "NoExecute"
      EOT
    }
  }
}

resource "kubernetes_manifest" "rke2-snapshot-controller-helm-chart-config" {
  field_manager {
    force_conflicts = true
  }
  manifest = {
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "rke2-snapshot-controller"
      namespace = "kube-system"
    }
    spec = {
      valuesContent = <<-EOT
        controller:
          tolerations:
          - key: "cwm-iac-worker-role"
            operator: "Equal"
            value: "system"
            effect: "NoExecute"
      EOT
    }
  }
}

resource "kubernetes_manifest" "rke2-ingress-nginx-helm-chart-config" {
  field_manager {
    force_conflicts = true
  }
  manifest = {
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "rke2-ingress-nginx"
      namespace = "kube-system"
    }
    spec = {
      valuesContent = <<-EOT
        tolerations:
          - key: "cwm-iac-worker-role"
            operator: "Equal"
            value: "system"
            effect: "NoExecute"
        controller:
          tolerations:
            - key: "cwm-iac-worker-role"
              operator: "Equal"
              value: "minio"
              effect: "NoExecute"
          config:
            # this is required for cert-manager, see https://cert-manager.io/docs/releases/release-notes/release-notes-1.18/
            strict-validate-path-type: false
          admissionWebhooks:
            patch:
              tolerations:
                - key: "cwm-iac-worker-role"
                  operator: "Equal"
                  value: "system"
                  effect: "NoExecute"
        defaultBackend:
          tolerations:
            - key: "cwm-iac-worker-role"
              operator: "Equal"
              value: "system"
              effect: "NoExecute"
      EOT
    }
  }
}

resource "null_resource" "rke2-fix-helm-install-jobs" {
  triggers = {
    hash = sha256(jsonencode([
      kubernetes_manifest.rke2-coredns-helm-chart-config.manifest,
      kubernetes_manifest.rke2-metrics-server-helm-chart-config.manifest,
      kubernetes_manifest.rke2-snapshot-controller-helm-chart-config.manifest,
      kubernetes_manifest.rke2-ingress-nginx-helm-chart-config.manifest
    ]))
    command = <<-EOT
      set -euo pipefail
      sleep 10
      for POD in "$(${local.kubectl} -n kube-system get pods -oname | grep helm-install)"; do
        ${local.kubectl} -n kube-system patch $POD --type=json --patch '[{"op": "add","path": "/spec/tolerations/-","value": {"key": "cwm-iac-worker-role","operator": "Equal","value": "system","effect": "NoExecute"}}]' \
          || true
      done
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}
