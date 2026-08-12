resource "kamatera_network" "private" {
  count = var.use_existing_private_network_full_name != "" ? 0 : 1
  datacenter_id = var.datacenter_id
  name          = var.private_network_name
  subnet {
    ip = "172.16.0.0"
    bit = 23
  }
}
