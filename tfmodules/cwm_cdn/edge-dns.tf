resource "aws_route53_record" "edge" {
  provider = aws.route53
  name    = "edge.${var.name_prefix}.${var.zone_domain}"
  type    = "A"
  zone_id = var.zone_id
  records = var.edge_server_public_ips
  ttl = 300
}

output "edge_dns" {
  value = aws_route53_record.edge.name
}
