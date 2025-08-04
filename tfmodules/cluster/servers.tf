resource "kamatera_server" "servers" {
  for_each = var.servers
  datacenter_id = var.datacenter_id
  image_id = var.image_id
  name = each.value.kamatera_server_name != null ? each.value.kamatera_server_name : "${var.name_prefix}-${each.key}"
  allow_recreate = true
  billing_cycle = each.value.billing_cycle != null ? each.value.billing_cycle : var.default_billing_cycle
  cpu_cores = each.value.cpu_cores
  cpu_type = each.value.cpu_type
  daily_backup = each.value.daily_backup != null ? each.value.daily_backup : var.default_daily_backup
  disk_sizes_gb = each.value.disk_sizes_gb
  managed = each.value.managed != null ? each.value.managed : var.default_managed
  monthly_traffic_package = each.value.monthly_traffic_package != null ? each.value.monthly_traffic_package : var.default_monthly_traffic_package
  ram_mb = each.value.ram_mb
  ssh_pubkey = var.ssh_pubkey

  network {
    name = "wan"
  }

  network {
    name = kamatera_network.private.full_name
  }

  lifecycle {
    ignore_changes = [ssh_pubkey]
  }
}

locals {
  server_public_ip = {
    for name, _ in var.servers : name => kamatera_server.servers[name].public_ips[0]
  }
  server_private_ip = {
    for name, _ in var.servers : name => kamatera_server.servers[name].private_ips[0]
  }
  bastion_server_name = [
    for name, server in var.servers : name if server.role == "bastion"
  ][0]
}
