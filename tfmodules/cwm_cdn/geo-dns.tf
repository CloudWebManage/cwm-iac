resource "aws_route53_record" "geo" {
  count = var.geolocation_set_identifier == "" ? 0 : (length(var.geolocation_routing_policies) > 0 ? 0 : 1)
  provider = aws.route53
  name    = "${var.geo_prefix}.${var.zone_domain}"
  type    = "CNAME"
  zone_id = var.zone_id
  records = [aws_route53_record.edge.name]
  ttl = 300
  set_identifier = var.geolocation_set_identifier
  geolocation_routing_policy {
    continent = lookup(var.geolocation_routing_policy, "continent", null)
    country   = lookup(var.geolocation_routing_policy, "country", null)
    subdivision = lookup(var.geolocation_routing_policy, "subdivision", null)
  }
}

resource "aws_route53_record" "geos" {
  for_each = var.geolocation_routing_policies
  provider = aws.route53
  name    = "${var.geo_prefix}.${var.zone_domain}"
  type    = "CNAME"
  zone_id = var.zone_id
  records = [aws_route53_record.edge.name]
  ttl = 300
  set_identifier = "${var.geolocation_set_identifier}-${each.key}"
  geolocation_routing_policy {
    continent = lookup(each.value, "continent", null)
    country   = lookup(each.value, "country", null)
    subdivision = lookup(each.value, "subdivision", null)
  }
}
