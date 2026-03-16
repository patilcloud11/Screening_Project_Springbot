###############################################################################
# modules/acm/main.tf  –  ACM Certificate (must be in us-east-1 for CloudFront)
###############################################################################

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-cert-${var.environment}"
    Environment = var.environment
  }
}

# ── Output the DNS validation records so you can add them to GoDaddy / Route53
# After adding the CNAME records, run: terraform apply again to mark as validated
resource "aws_acm_certificate_validation" "main" {
  certificate_arn = aws_acm_certificate.main.arn

  # Validation record FQDNs must be added to GoDaddy DNS manually OR
  # via a Route53 hosted zone. Timeout set to 45 min for manual DNS propagation.
  timeouts {
    create = "45m"
  }
}
