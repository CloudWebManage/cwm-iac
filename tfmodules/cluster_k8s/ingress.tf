locals {
  ingress_server_records = [for name, server in var.servers : local.server_public_ip[name] if server.ingress == true]
}

resource "aws_route53_record" "ingress" {
  provider = aws.route53
  count = length(local.ingress_server_records) > 0 ? 1 : 0
  name    = "ingress.${var.name_prefix}.${var.ingress_dns_zone_domain}"
  type    = "A"
  zone_id = var.ingress_dns_zone_id
  records = local.ingress_server_records
  ttl = 300
}

resource "aws_route53_record" "ingress_star" {
  provider = aws.route53
  count = length(local.ingress_server_records) > 0 ? 1 : 0
  name    = "*.${var.name_prefix}.${var.ingress_dns_zone_domain}"
  type    = "CNAME"
  zone_id = var.ingress_dns_zone_id
  records = [aws_route53_record.ingress[0].name]
  ttl = 300
}

output "ingress_star_domain" {
  value = length(local.ingress_server_records) > 0 ? "${var.name_prefix}.${var.ingress_dns_zone_domain}" : ""
}
