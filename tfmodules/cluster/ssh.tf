resource "random_integer" "bastion_ssh_port" {
  min = 1025
  max = 65535
}

resource "random_integer" "servers_ssh_port" {
  min = 52000
  max = 65535
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
    v = 2
    command = replace(
      local.init_ssh_script_template,
      "__LISTEN_ADDR__",
      "0.0.0.0:${random_integer.bastion_ssh_port.result}"
    )
  }
  provisioner "local-exec" {
    command = <<-EOF
      set -euo pipefail
      mkdir -p ${path.root}/servers/${each.key}
      if [ -f ${path.root}/servers/${each.key}/ssh_known_hosts ]; then FIRST_RUN=no; else FIRST_RUN=yes; fi
      if [ "$FIRST_RUN" == "yes" ]; then
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            root@${local.server_public_ip[each.key]} "${self.triggers.command}"
      fi
      ssh-keyscan \
        -p ${random_integer.bastion_ssh_port.result} \
        ${local.server_public_ip[each.key]} \
          > ${path.root}/servers/${each.key}/ssh_known_hosts
      if [ "$FIRST_RUN" == "no" ]; then
        ssh -o UserKnownHostsFile=${path.root}/servers/${each.key}/ssh_known_hosts \
            -p ${random_integer.bastion_ssh_port.result} \
            root@${local.server_public_ip[each.key]} "${self.triggers.command}"
      fi
    EOF
    interpreter = ["bash", "-c"]
  }
}

resource "null_resource" "init_ssh_servers" {
  for_each = {for name, server in var.servers : name => server if server.role != "bastion"}
  depends_on = [kamatera_server.servers, null_resource.init_ssh_bastion]
  triggers = {
    v = 2
    command = replace(
      local.init_ssh_script_template,
      "__LISTEN_ADDR__",
      "${local.server_private_ip[each.key]}:${random_integer.servers_ssh_port.result}"
    )
  }
  provisioner "local-exec" {
    command = <<-EOF
      set -euo pipefail
      mkdir -p ${path.root}/servers/${each.key}
      if [ -f ${path.root}/servers/${each.key}/ssh_known_hosts ]; then FIRST_RUN=no; else FIRST_RUN=yes; fi
      if [ "$FIRST_RUN" == "yes" ]; then
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            root@${local.server_public_ip[each.key]} "${self.triggers.command}"
      fi
      ssh -o UserKnownHostsFile=${path.root}/servers/${local.bastion_server_name}/ssh_known_hosts \
          -p ${random_integer.bastion_ssh_port.result} \
          root@${local.server_public_ip[local.bastion_server_name]} \
            "ssh-keyscan -p ${random_integer.servers_ssh_port.result} ${local.server_private_ip[each.key]}" \
              > ${path.root}/servers/${each.key}/ssh_known_hosts
      if [ "$FIRST_RUN" == "no" ]; then
        ssh -o UserKnownHostsFile=${path.root}/servers/${each.key}/ssh_known_hosts \
            -p ${random_integer.servers_ssh_port.result} \
            -J root@${local.server_public_ip[local.bastion_server_name]}:${random_integer.bastion_ssh_port.result} \
            root@${local.server_private_ip[each.key]} "${self.triggers.command}"
      fi
    EOF
    interpreter = ["bash", "-c"]
  }
}

locals {
  servers_ssh_command = {
    for name, server in var.servers : name =>
      "ssh -o UserKnownHostsFile=${path.root}/servers/${name}/ssh_known_hosts -p ${random_integer.servers_ssh_port.result} -J root@${local.server_public_ip[local.bastion_server_name]}:${random_integer.bastion_ssh_port.result} root@${local.server_private_ip[name]}"
  }
}

resource "local_file" "servers_ssh_config" {
  filename = "${path.root}/servers/ssh_config"
  content = join("\n", [
    <<-EOT
        Host ${var.name_prefix}-bastion
          HostName ${local.server_public_ip[local.bastion_server_name]}
          User root
          Port ${random_integer.bastion_ssh_port.result}
          UserKnownHostsFile ${abspath("${path.root}/servers/${local.bastion_server_name}/ssh_known_hosts")}
    EOT
    ,
    join("\n", [
        for name, server in {for k, v in var.servers: k => v if v.role != "bastion"} : <<-EOT
            Host ${var.name_prefix}-${name}
              HostName ${local.server_private_ip[name]}
              User root
              Port ${random_integer.servers_ssh_port.result}
              ProxyJump ${var.name_prefix}-bastion
              UserKnownHostsFile ${abspath("${path.root}/servers/${name}/ssh_known_hosts")}
        EOT
      ])
  ])
}
