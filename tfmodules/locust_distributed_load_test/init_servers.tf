resource "terraform_data" "init_servers" {
  depends_on = [local_file.ssh_config]
  for_each = toset(concat(
    ["main"],
    [for name, worker in kamatera_server.workers : name]
  ))
  triggers_replace = {
    script = <<-EOT
      set -euo pipefail
      ssh -F ${var.data_path}/ssh_config ${var.name_prefix}-${each.value} 'bash -s' <<-'EOF'
        set -euo pipefail
        apt update
        apt install -y ca-certificates curl
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        tee /etc/apt/sources.list.d/docker.sources <<EOZ
      Types: deb
      URIs: https://download.docker.com/linux/ubuntu
      Suites: noble
      Components: stable
      Signed-By: /etc/apt/keyrings/docker.asc
      EOZ
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        shutdown -r now
      EOF
    EOT
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = self.triggers_replace.script
  }
}

locals {
  locust_env_config = join("\n", [
    for key, value in var.locust_env_config : "${key}=${value}"
  ])
}

resource "terraform_data" "init_locust_main" {
  depends_on = [terraform_data.init_servers]
  triggers_replace = {
    start_main_hash = filemd5("${path.module}/start_main.sh")
    script = <<-EOT
      set -euo pipefail
      scp -F ${var.data_path}/ssh_config "${path.module}/start_main.sh" ${var.name_prefix}-main:/root/start_main.sh
      ssh -F ${var.data_path}/ssh_config ${var.name_prefix}-main 'bash -s' <<-'EOF'
        set -euo pipefail
        echo "${local.locust_env_config}" > /root/locust.env
        chmod +x /root/start_main.sh
      EOF
    EOT
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = self.triggers_replace.script
  }
}

resource "terraform_data" "init_locust_workers" {
  depends_on = [terraform_data.init_servers]
  for_each = toset([for name, worker in var.workers : name])
  triggers_replace = {
    start_worker_hash = filemd5("${path.module}/start_worker.sh")
    script = <<-EOT
      set -euo pipefail
      scp -F ${var.data_path}/ssh_config "${path.module}/start_worker.sh" ${var.name_prefix}-${each.key}:/root/start_worker.sh
      ssh -F ${var.data_path}/ssh_config ${var.name_prefix}-${each.key} 'bash -s' <<-'EOF'
        set -euo pipefail
        if ! which autossh; then
          apt update
          apt install -y autossh
        fi
        cat >/etc/systemd/system/locust-ssh-tunnel.service <<-EOZ
      [Unit]
      Description=Locust SSH Tunnel (autossh)
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=simple
      User=root
      Environment="AUTOSSH_GATETIME=0"
      Environment="AUTOSSH_LOGFILE=/var/log/autossh-locust.log"
      ExecStart=/usr/bin/autossh \
        -M 0 \
        -N \
        -L 172.17.0.1:5557:localhost:5557 \
        -L 172.17.0.1:6379:localhost:6379 \
        -o ExitOnForwardFailure=yes \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        cwmc-dlt-main
      Restart=always
      RestartSec=5
      KillMode=process
      TimeoutStopSec=10
      StandardOutput=append:/var/log/locust-tunnel.log
      StandardError=append:/var/log/locust-tunnel.log
      [Install]
      WantedBy=multi-user.target
      EOZ
        systemctl daemon-reload
        systemctl enable --now locust-ssh-tunnel.service
        systemctl restart locust-ssh-tunnel
        echo "${local.locust_env_config}" > /root/locust.env
        chmod +x /root/start_worker.sh
      EOF
    EOT
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = self.triggers_replace.script
  }
}
