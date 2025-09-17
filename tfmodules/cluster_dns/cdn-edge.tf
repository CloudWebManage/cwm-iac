resource "aws_route53_record" "cdn-edge" {
  count = var.cdn.enabled ? 1 : 0
  name    = "edge.${var.name_prefix}.${var.cdn.zone_domain}"
  type    = "A"
  zone_id = var.cdn.zone_id
  records = [for server in var.cdn.edge_servers : server.public_ip]
  ttl = 300
}

output "cdn_edge_dns" {
  value = var.cdn.enabled ? aws_route53_record.cdn-edge[0].name : ""
}
