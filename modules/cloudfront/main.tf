###############################################################################
# modules/cloudfront/main.tf  –  CloudFront CDN with WAF + ACM
###############################################################################

locals {
  alb_origin_id = "alb-origin"
  s3_origin_id  = "s3-static-origin"
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  comment             = "${var.project_name} CDN (${var.environment})"
  default_root_object = "index.html"
  price_class         = var.price_class
  web_acl_id          = var.waf_web_acl_arn
  aliases             = [var.domain_name, "www.${var.domain_name}"]

  # ── Origin 1: S3 (static frontend assets) ─────────────────────────────────
  origin {
    domain_name = var.s3_frontend_bucket
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  # ── Origin 2: ALB (dynamic requests) ──────────────────────────────────────
  origin {
    domain_name = var.alb_dns_name
    origin_id   = local.alb_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.origin_secret.result
    }
  }

  # ── Behaviour: Static assets → S3 ─────────────────────────────────────────
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # ── Behaviour: API calls → ALB (no cache) ─────────────────────────────────
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.alb_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Origin", "Accept", "Content-Type"]
      cookies { forward = "all" }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # ── Default Behaviour → ALB ────────────────────────────────────────────────
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.alb_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Origin", "Host"]
      cookies { forward = "all" }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # ── Custom Error Responses ─────────────────────────────────────────────────
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  # ── TLS / Viewer Certificate ───────────────────────────────────────────────
  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  tags = { Name = "${var.project_name}-cf-${var.environment}" }
}

# ── Origin Access Identity (CloudFront → S3) ──────────────────────────────────
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "${var.project_name} OAI (${var.environment})"
}

# ── S3 Bucket Policy: allow only OAI ──────────────────────────────────────────
data "aws_iam_policy_document" "s3_cf" {
  statement {
    sid     = "AllowCloudFrontOAI"
    actions = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${replace(var.s3_frontend_bucket, ".s3.${data.aws_region.current.name}.amazonaws.com", "")}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }
}

data "aws_region" "current" {}

# ── Random secret shared between CloudFront and ALB ───────────────────────────
resource "random_password" "origin_secret" {
  length  = 32
  special = false
}
