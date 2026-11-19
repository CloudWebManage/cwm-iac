resource "aws_route53_record" "geos" {
  for_each = tomap({
    for pair in setproduct(concat(["default"], keys(var.additional_geo_prefixes)), keys(var.geolocation_routing_policies)) : "${pair[0]}-${pair[1]}" => {
      prefix = pair[0]
      key    = pair[1]
      value  = var.geolocation_routing_policies[pair[1]]
    }
  })
  provider = aws.route53
  name    = "${each.value.prefix == "default" ? var.geo_prefix : each.value.prefix}.${var.zone_domain}"
  type    = "CNAME"
  zone_id = var.zone_id
  records = [each.value.prefix == "default" ? aws_route53_record.edge.name : "${var.additional_geo_prefixes[each.value.prefix]}.${var.zone_domain}"]
  ttl = 300
  set_identifier = "${var.geolocation_set_identifier}-${each.value.prefix}-${each.value.key}"
  geolocation_routing_policy {
    continent = lookup(each.value.value, "continent", null)
    country   = lookup(each.value.value, "country", null)
    subdivision = lookup(each.value.value, "subdivision", null)
  }
}
