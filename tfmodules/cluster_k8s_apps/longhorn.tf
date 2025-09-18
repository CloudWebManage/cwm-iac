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


module "longhorn-app" {
  depends_on = [null_resource.longhorn_init_nodes]
  source = "app.terraform.io/cwm-iac/argocd-app/generic"
  version = "v0.0.0+b6f64d0ad39a458c0d236e5bdbfc7fc4c55535b0"
  name = "longhorn"
  namespace = "longhorn-system"
}
