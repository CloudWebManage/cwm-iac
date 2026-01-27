resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "ssh_private_key" {
  filename = "${var.data_path}/id_rsa"
  content  = tls_private_key.ssh_key.private_key_pem
  file_permission = "0400"
}

resource "local_file" "ssh_public_key" {
  filename = "${var.data_path}/id_rsa.pub"
  content  = tls_private_key.ssh_key.public_key_openssh
}

resource "terraform_data" "set_main_server_authorized_key" {
  depends_on = [terraform_data.init_servers, local_file.ssh_config]
  triggers_replace = {
    script = <<-EOT
      set -euo pipefail
      ssh -F ${var.data_path}/ssh_config ${var.name_prefix}-main 'bash -s' <<-'EOF'
        set -euo pipefail
        if cat ~/.ssh/authorized_keys | grep -q "${trimspace(tls_private_key.ssh_key.public_key_openssh)}"; then
          echo "SSH public key already present in authorized_keys"
        else
          echo "${tls_private_key.ssh_key.public_key_openssh}" >> ~/.ssh/authorized_keys
          echo "SSH public key added to authorized_keys"
        fi
      EOF
    EOT
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = self.triggers_replace.script
  }
}

resource "terraform_data" "set_workers_private_key" {
  depends_on = [terraform_data.init_servers, local_file.ssh_config]
  for_each = toset([for name, worker in var.workers : name])
  triggers_replace = {
    script = <<-EOT
      set -euo pipefail
      ssh -F ${var.data_path}/ssh_config ${var.name_prefix}-${each.key} 'bash -s' <<-'EOF'
        set -euo pipefail
        echo "${tls_private_key.ssh_key.private_key_pem}" > ~/.ssh/id_rsa
        chmod 400 ~/.ssh/id_rsa
        cat > ~/.ssh/config <<-EOZ
      Host cwmc-dlt-main
        HostName ${kamatera_server.main.public_ips[0]}
        User root
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
      EOZ
      EOF
    EOT
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = self.triggers_replace.script
  }
}
