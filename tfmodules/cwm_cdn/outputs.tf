output "api_creds" {
  value = {
    url      = "https://cwm-cdn-api.${var.name_prefix}.${var.zone_domain}"
    username = random_password.api-username.result
    password = random_password.api-password.result
  }
  sensitive = true
}

output "prometheus_creds" {
  value = {
    url      = "https://cwm-cdn-api-prometheus.${var.name_prefix}.${var.zone_domain}"
    username = random_password.api-username.result
    password = random_password.api-password.result
  }
  sensitive = true
}

output "cdn_pop_id" {
  value = local.cdn_pop_id
}

output "geo_dns_records" {
  value = {
    name       = "${var.geo_prefix}.${var.zone_domain}"
    edge_cname = aws_route53_record.edge.name
    records = concat(
      [for record in aws_route53_record.geo : record.fqdn],
      [for record in aws_route53_record.geos : record.fqdn]
    )
  }
}

output "route53_pop_health_dns_automation" {
  value = {
    enabled = var.route53_pop_health_dns_automation_enabled
    dry_run = var.route53_pop_health_dns_dry_run_enabled
    note    = "Automatic Route53 POP health DNS writes are disabled; use this output for manual readiness/dry-run workflows only."
  }
}
