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
  source = "../argocd-app"
  name = "longhorn"
  namespace = "longhorn-system"
  values = {
    "htpasswdVaultPath": "${var.vault_path}/longhorn/htpasswd"
    longhorn = {
      ingress = {
        host = "longhorn.${var.ingress_star_domain}"
      }
    }
  }
}

module "longhorn_htpasswd" {
  source = "../htpasswd"
  tools = var.tools
  vault_mount = var.vault_mount
  vault_path = "${var.vault_path}/longhorn/htpasswd"
  vault_kv_put_extra_args = "longhorn_url=\"https://longhorn.${var.ingress_star_domain}\""
  secrets = []
}
