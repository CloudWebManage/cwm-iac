data "kamatera_image" "workers_ubuntu_2404" {
  for_each = var.workers
  datacenter_id = each.value.datacenter_id
  os = "Ubuntu"
  code = "24.04 64bit"
}

resource "kamatera_server" "workers" {
  for_each = var.workers
  datacenter_id = each.value.datacenter_id
  image_id = data.kamatera_image.workers_ubuntu_2404[each.key].id
  name = "${var.name_prefix}-${each.key}"
  billing_cycle = "hourly"
  cpu_cores = 2
  cpu_type = "B"
  disk_sizes_gb = [20]
  ram_mb = 2048
  ssh_pubkey = var.ssh_pubkey
  network {
    name = "wan"
  }
  lifecycle {
    ignore_changes = [ssh_pubkey]
  }
}
