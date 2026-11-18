resource "terraform_data" "get_network_interfaces" {
  for_each = {for name, server in var.servers : name => server if !contains(["bastion", "standalone"], server.role)}
  depends_on = [null_resource.rke2_install_workers]
  triggers_replace = {
    script = <<-EOT
      set -euo pipefail
      FILENAME_INTERNAL="${var.data_path}/servers/${each.key}/iface_internal"
      FILENAME_PUBLIC="${var.data_path}/servers/${each.key}/iface_public"
      if [ ! -f "$FILENAME_INTERNAL" ]; then
        ${local.servers_ssh_command[each.key]} "ip -o -4 addr show scope global | awk '\$4 ~ /^172\.16\./ {print \$2}' | sort -u" > "$FILENAME_INTERNAL"
      fi
      if [ ! -f "$FILENAME_PUBLIC" ]; then
        ${local.servers_ssh_command[each.key]} "ip -4 route show default | awk '/^default/ {for (i=1; i<=NF; i++) if (\$i==\"dev\") {print \$(i+1); exit}}'" > "$FILENAME_PUBLIC"
      fi
    EOT
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = self.triggers_replace.script
  }
}