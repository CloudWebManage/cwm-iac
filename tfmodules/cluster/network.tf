resource "kamatera_network" "private" {
  datacenter_id = var.datacenter_id
  name          = var.private_network_name
  subnet {
    ip = "172.16.0.0"
    bit = 23
  }
}
