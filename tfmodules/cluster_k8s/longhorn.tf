locals {
  longhorn_version = "v1.9.1"
}

resource "null_resource" "longhorn_init_nodes" {
  for_each = {
    for name, worker in var.workers : name => worker if worker.worker-role == "system"
  }
  triggers = {
    counter = lookup(var.force_reinstall_counters, "longhorn_init_nodes", 0)
    command = <<-EOT
      set -euo pipefail
      ${var.servers_ssh_command[each.key]} "
        apt-get update -y
        apt-get install -y open-iscsi nfs-common cryptsetup dmsetup
        modprobe iscsi_tcp
      "
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}


resource "kubernetes_manifest" "longhorn-app" {
  depends_on = [null_resource.longhorn_init_nodes, null_resource.argocd_install]
  manifest = yamldecode(<<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: longhorn
      namespace: argocd
    spec:
      destination:
        namespace: longhorn
        server: 'https://kubernetes.default.svc'
      project: default
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
      source:
        repoURL: https://github.com/CloudWebManage/cwm-iac
        targetRevision: main
        path: apps/longhorn
  EOT
  )
}
