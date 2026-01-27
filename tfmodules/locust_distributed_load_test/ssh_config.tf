resource "local_file" "ssh_config" {
  filename = "${var.data_path}/ssh_config"
  content = join("\n", concat([
    <<-EOT
      Host ${var.name_prefix}-main
        HostName ${kamatera_server.main.public_ips[0]}
        User root
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
    EOT
  ],[
    for name, worker in var.workers : <<-EOT
      Host ${var.name_prefix}-${name}
        HostName ${kamatera_server.workers[name].public_ips[0]}
        User root
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
    EOT
  ]))
}
