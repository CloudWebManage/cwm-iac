resource "null_resource" "rke2_node_settings" {
  for_each = {for name, server in var.servers : name => server if server.role != "bastion"}
  depends_on = [null_resource.init_ssh_servers]
  triggers = {
    command = <<-EOF
      set -euo pipefail
      echo 'vm.max_map_count = 262144' > /etc/sysctl.d/99-cwm.conf
      echo 'net.ipv4.tcp_retries2 = 8' >> /etc/sysctl.d/99-cwm.conf
      echo 'fs.inotify.max_user_instances = 1024' >> /etc/sysctl.d/99-cwm.conf
      echo 'fs.inotify.max_user_watches   = 2097152' >> /etc/sysctl.d/99-cwm.conf
      echo 'fs.inotify.max_queued_events  = 65536' >> /etc/sysctl.d/99-cwm.conf
      echo 'net.core.somaxconn = 65535' >> /etc/sysctl.d/99-cwm.conf
      echo 'net.core.netdev_max_backlog = 16384' >> /etc/sysctl.d/99-cwm.conf
      echo 'net.ipv4.tcp_max_syn_backlog = 8192' >> /etc/sysctl.d/99-cwm.conf
      sysctl --system
      rm -f /etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf
      systemctl daemon-reload
      systemctl restart systemd-networkd-wait-online.service
      if ! [ -e /root/.ssh/id_rsa ]; then ssh-keygen -t rsa -b 4096 -N '' -f /root/.ssh/id_rsa; fi
      echo 'export PATH="/var/lib/rancher/rke2/bin/:$PATH"' > /etc/profile.d/00-cwm.sh
      echo 'export CRI_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/crictl.yaml' >> /etc/profile.d/00-cwm.sh
      echo 'export CONTAINERD_ADDRESS=/run/k3s/containerd/containerd.sock' >> /etc/profile.d/00-cwm.sh
      echo 'export CONTAINERD_NAMESPACE=k8s.io' >> /etc/profile.d/00-cwm.sh
      echo 'export KUBECONFIG="/etc/rancher/rke2/rke2.yaml"' >> /etc/profile.d/00-cwm.sh
    EOF
  }
  provisioner "local-exec" {
    command = <<-EOT
      ${local.servers_ssh_command[each.key]} "${self.triggers.command}"
    EOT
  }
}

locals {
  controlplane1_server_name = [for name, server in var.servers : name if server.role == "controlplane1"][0]
  controlplane1_private_ip = local.server_private_ip[local.controlplane1_server_name]
  controlplane1_public_ip = local.server_public_ip[local.controlplane1_server_name]
}

resource "null_resource" "rke2_install_controlplane1" {
  depends_on = [null_resource.rke2_node_settings]
  triggers = {
    config = <<-EOF
      node-name: controlplane1
      node-ip: ${local.controlplane1_private_ip}
      node-external-ip: ${local.controlplane1_public_ip}
      advertise-address: ${local.controlplane1_private_ip}
      tls-san:
        - 0.0.0.0
        - ${local.controlplane1_private_ip}
        - ${local.controlplane1_public_ip}
      etcd-snapshot-retention: 14  # snapshot every 12 hours, total of 1 week
    EOF
    command = <<-EOF
      curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${var.rke2_version} sh - &&\
      if systemctl is-active --quiet rke2-server.service; then
        systemctl restart rke2-server.service
      else
        systemctl enable rke2-server.service &&\
        systemctl start rke2-server.service
      fi
    EOF
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      ${local.servers_ssh_command[local.controlplane1_server_name]} "mkdir -p /etc/rancher/rke2"
      echo "${self.triggers.config}" | ${local.servers_ssh_command[local.controlplane1_server_name]} "cat > /etc/rancher/rke2/config.yaml"
      ${local.servers_ssh_command[local.controlplane1_server_name]} "${self.triggers.command}"
    EOT
    interpreter = ["bash", "-c"]
  }
}

resource "null_resource" "rke2_install_workers" {
  for_each = {for name, server in var.servers : name => server if server.role == "worker"}
  depends_on = [null_resource.rke2_install_controlplane1]
  triggers = {
    config = <<-EOF
      node-name: ${each.key}
      node-ip: ${local.server_private_ip[each.key]}
      node-external-ip: ${local.server_public_ip[each.key]}
      token-file: /etc/rancher/rke2/node-token
      server: https://${local.controlplane1_private_ip}:9345
    EOF
    command = <<-EOF
      curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${var.rke2_version} INSTALL_RKE2_TYPE=agent sh - &&\
      if systemctl is-active --quiet rke2-agent.service; then
        systemctl restart rke2-agent.service
      else
        systemctl enable rke2-agent.service &&\
        systemctl start rke2-agent.service
      fi
    EOF
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      ${local.servers_ssh_command[each.key]} "mkdir -p /etc/rancher/rke2"
      echo "${self.triggers.config}" | ${local.servers_ssh_command[each.key]} "cat > /etc/rancher/rke2/config.yaml"
      ${local.servers_ssh_command[each.key]} "${self.triggers.command}"
    EOT
    interpreter = ["bash", "-c"]
  }
}
