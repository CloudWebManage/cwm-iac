locals {
  controlplane_server_records = [
    for name, config in var.servers : local.server_public_ip[name]
    if config.role == "controlplane" || config.role == "controlplane1"
  ]
}


resource "aws_route53_record" "controlplane" {
  provider = aws.route53
  name    = "controlplane.${var.name_prefix}.${var.ingress_dns_zone_domain}"
  type    = "A"
  zone_id = var.ingress_dns_zone_id
  records = local.controlplane_server_records
  ttl = 300
}
