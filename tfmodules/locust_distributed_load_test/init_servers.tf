resource "terraform_data" "init_servers" {
  for_each = concat(
    [kamatera_server.main.public_ips[0]],
    [for worker in kamatera_server.workers : worker.public_ips[0]]
  )

}