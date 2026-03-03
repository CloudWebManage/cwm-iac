resource "terraform_data" "network_interfaces" {
  depends_on = [null_resource.rke2_install_workers]
  for_each = var.servers
  triggers_replace = {
    command = <<-EOT
      set -euo pipefail
      ${local.servers_ssh_command[each.key]} ip -j addr show \
        | python3 ${path.module}/parse_network_interfaces.py \
        > "${var.data_path}/servers/${each.key}/network_interfaces.json"
    EOT
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = self.triggers_replace.command
  }
}
