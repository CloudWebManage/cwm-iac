resource "aws_route53_record" "geo" {
  count = var.geolocation_set_identifier == "" ? 0 : 1
  provider = aws.route53
  name    = "geo.${var.zone_domain}"
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
