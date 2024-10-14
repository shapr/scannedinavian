variable "domain_validation_options" {
  type = list
}

variable "zone_id" {
  type = string
}

resource "aws_route53_record" "main" {
  for_each = {
    for dvo in var.domain_validation_options : dvo.domain_name => {
      name = dvo.resource_record_name
      record = dvo.resource_record_value
      type = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name = each.value.name
  records = [each.value.record]
  ttl = 60
  type = each.value.type
  zone_id = var.zone_id
}

output "validation_record_fqdns" {
  value = [for record in aws_route53_record.main : record.fqdn]
}
