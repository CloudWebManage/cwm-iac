data "kamatera_image" "main_ubuntu_2404" {
  datacenter_id = var.main_server_datacenter_id
  os = "Ubuntu"
  code = "24.04 64bit"
}

resource "kamatera_server" "main" {
  datacenter_id = var.main_server_datacenter_id
  image_id = data.kamatera_image.main_ubuntu_2404.id
  name = "${var.name_prefix}-main"
  billing_cycle = "hourly"
  cpu_cores = 4
  cpu_type = "B"
  disk_sizes_gb = [20]
  ram_mb = 8192
  ssh_pubkey = var.ssh_pubkey
  network {
    name = "wan"
  }
  lifecycle {
    ignore_changes = [ssh_pubkey]
  }
}
