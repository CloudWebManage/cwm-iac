resource "terraform_data" "create_vmaggregator_disk" {
  triggers_replace = [
    <<-EOT
      set -euo pipefail
      ssh ${var.config.storage.server_name} "
        set -euo pipefail
        if ! [ -d '${var.config.storage.mount_path}' ]; then
          mkfs.ext4 '${var.config.storage.device_path}'
          mkdir -p '${var.config.storage.mount_path}'
          echo '${var.config.storage.device_path} ${var.config.storage.mount_path} ext4 defaults 0 2' >> /etc/fstab
          mount -a
        fi
        mkdir -p '${var.config.storage.mount_path}/main-vmsingle'
      "
    EOT
  ]
  provisioner "local-exec" {
    command = self.triggers_replace[0]
    interpreter = ["bash", "-c"]
  }
}
