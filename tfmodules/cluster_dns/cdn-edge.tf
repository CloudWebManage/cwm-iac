resource "aws_route53_record" "cdn-edge" {
  count = var.cdn.enabled ? 1 : 0
  name    = "edge.${var.name_prefix}.${var.cdn.zone_domain}"
  type    = "A"
  zone_id = var.zone_id
  records = [for server in var.cdn.edge_servers : server.public_ip]
  ttl = 300
}
