output "certificate_arn"    { value = aws_acm_certificate_validation.main.certificate_arn }
output "domain_name"        { value = aws_acm_certificate.main.domain_name }

# Expose DNS validation records so operators can add CNAMEs to GoDaddy
output "validation_records" {
  description = "DNS CNAME records to add to GoDaddy for certificate validation"
  value = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}
