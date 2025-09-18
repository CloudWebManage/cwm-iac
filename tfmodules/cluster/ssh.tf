resource "random_integer" "bastion_ssh_port" {
  min = 1025
  max = 65535
}

output "bastion_ssh_port" {
  value = random_integer.bastion_ssh_port.result
}

resource "random_integer" "servers_ssh_port" {
  min = 52000
  max = 65535
}

output "servers_ssh_port" {
  value = random_integer.servers_ssh_port.result
}

locals {
  init_ssh_script_template = <<-EOF
    echo ${base64encode(var.ssh_pubkey)} | base64 -d > .ssh/authorized_keys &&\
    if [ -f /etc/ssh/sshd_config.d/50-cloud-init.conf ]; then
      sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf
    fi &&\
    mkdir -p /etc/systemd/system/ssh.socket.d &&\
    echo '[Socket]' > /etc/systemd/system/ssh.socket.d/override.conf &&\
    echo 'ListenStream=' >> /etc/systemd/system/ssh.socket.d/override.conf &&\
    echo 'ListenStream=__LISTEN_ADDR__' >> /etc/systemd/system/ssh.socket.d/override.conf &&\
    systemctl daemon-reload &&\
    systemctl restart ssh.socket &&\
    systemctl restart ssh.service
  EOF
}

resource "null_resource" "init_ssh_bastion" {
  for_each = {for name, server in var.servers : name => server if server.role == "bastion"}
  depends_on = [kamatera_server.servers]
  triggers = {
    v = 3
    command = replace(
      local.init_ssh_script_template,
      "__LISTEN_ADDR__",
      "0.0.0.0:${random_integer.bastion_ssh_port.result}"
    )
  }
  provisioner "local-exec" {
    command = <<-EOF
      set -euo pipefail
      SSHCMD="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${local.server_public_ip[each.key]}"
      if $SSHCMD -p ${random_integer.bastion_ssh_port.result} true; then
        $SSHCMD -p ${random_integer.bastion_ssh_port.result} "${self.triggers.command}"
      else
        $SSHCMD "${self.triggers.command}"
      fi
    EOF
    interpreter = ["bash", "-c"]
  }
}

resource "null_resource" "init_ssh_servers" {
  for_each = {for name, server in var.servers : name => server if server.role != "bastion"}
  depends_on = [null_resource.init_ssh_bastion]
  triggers = {
    command = replace(
      local.init_ssh_script_template,
      "__LISTEN_ADDR__",
      "${local.server_private_ip[each.key]}:${random_integer.servers_ssh_port.result}"
    )
  }
  provisioner "local-exec" {
    command = <<-EOF
      set -euo pipefail
      TMPFILE=$(mktemp)
      trap 'rm -f "$TMPFILE"' EXIT
      echo 'Host *' > "$TMPFILE"
      echo '  StrictHostKeyChecking no' >> "$TMPFILE"
      echo '  UserKnownHostsFile /dev/null' >> "$TMPFILE"
      SSHCMD="ssh -F $TMPFILE root@${local.server_private_ip[each.key]}"
      SSHCMD+=" -J root@${local.server_public_ip[local.bastion_server_name]}:${random_integer.bastion_ssh_port.result}"
      if $SSHCMD -p ${random_integer.servers_ssh_port.result} true; then
        $SSHCMD -p ${random_integer.servers_ssh_port.result} "${self.triggers.command}"
      else
        $SSHCMD "${self.triggers.command}"
      fi
    EOF
    interpreter = ["bash", "-c"]
  }
}

data "external" "ssh_known_hosts" {
  depends_on = [null_resource.init_ssh_servers]
  for_each = var.servers
  program = [
    "bash", "-c", <<-EOT
      set -euo pipefail
      FILENAME="${var.data_path}/servers/${each.key}/ssh_known_hosts"
      if ! [ -f "$FILENAME" ]; then
        mkdir -p "$(dirname "$FILENAME")"
        SERVER_ROLE="${each.value.role}"
        if [ "$SERVER_ROLE" = "bastion" ]; then
          ssh-keyscan -p ${random_integer.bastion_ssh_port.result} ${local.server_public_ip[each.key]} > "$FILENAME"
        else
          ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            root@${local.server_public_ip[local.bastion_server_name]} -p ${random_integer.bastion_ssh_port.result} \
              "ssh-keyscan -p ${random_integer.servers_ssh_port.result} ${local.server_private_ip[each.key]}" > "$FILENAME"
        fi
      fi
      echo '{}'
    EOT
  ]
}

locals {
  ssh_config = join("\n", [
    <<-EOT
        Host ${var.name_prefix}-bastion
          HostName ${local.server_public_ip[local.bastion_server_name]}
          User root
          Port ${random_integer.bastion_ssh_port.result}
          UserKnownHostsFile ${var.data_path}/servers/${local.bastion_server_name}/ssh_known_hosts
    EOT
    ,
    join("\n", [
        for name, server in {for k, v in var.servers: k => v if v.role != "bastion"} : <<-EOT
            Host ${var.name_prefix}-${name}
              HostName ${local.server_private_ip[name]}
              User root
              Port ${random_integer.servers_ssh_port.result}
              ProxyJump ${var.name_prefix}-bastion
              UserKnownHostsFile ${var.data_path}/servers/${name}/ssh_known_hosts
        EOT
      ])
  ])
  ssh_config_file = "${var.data_path}/servers/ssh_config"
}

resource "local_file" "ssh_config" {
  depends_on = [data.external.ssh_known_hosts]
  filename = "${var.data_path}/servers/ssh_config"
  content = local.ssh_config
}

locals {
  servers_ssh_command = {
    for name, server in var.servers : name =>
      "ssh -F ${local.ssh_config_file} ${var.name_prefix}-${name}"
  }
}

output "servers_ssh_command" {
  value = local.servers_ssh_command
}

output "ssh_config_file" {
  value = local.ssh_config_file
}
