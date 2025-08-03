resource "aws_route53_record" "ingress" {
  name    = "ingress.${var.name_prefix}.${var.zone_domain}"
  type    = "A"
  zone_id = var.zone_id
  records = [for server in var.ingress_servers : server.public_ip]
  ttl = 300
}

resource "aws_route53_record" "ingress_star" {
  name    = "*.${var.name_prefix}.${var.zone_domain}"
  type    = "CNAME"
  zone_id = var.zone_id
  records = [aws_route53_record.ingress.name]
  ttl = 300
}
