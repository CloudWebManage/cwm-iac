locals {
  ingress_server_records = [
    for name, worker in var.workers : worker.public-ip if worker.worker-role == var.ingress_nginx_controller_worker_role
  ]
  ingress_star_domain = length(local.ingress_server_records) > 0 ? "${var.cluster_name}.${var.ingress_dns_zone_domain}" : ""
}

resource "aws_route53_record" "ingress" {
  provider = aws.route53
  count = length(local.ingress_server_records) > 0 ? 1 : 0
  name    = "ingress.${var.cluster_name}.${var.ingress_dns_zone_domain}"
  type    = "A"
  zone_id = var.ingress_dns_zone_id
  records = local.ingress_server_records
  ttl = 300
}

resource "aws_route53_record" "ingress_star" {
  provider = aws.route53
  count = length(local.ingress_server_records) > 0 ? 1 : 0
  name    = "*.${var.cluster_name}.${var.ingress_dns_zone_domain}"
  type    = "CNAME"
  zone_id = var.ingress_dns_zone_id
  records = [aws_route53_record.ingress[0].name]
  ttl = 300
}

output "ingress_star_domain" {
  value = local.ingress_star_domain
}
