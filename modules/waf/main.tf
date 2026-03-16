###############################################################################
# modules/waf/main.tf  –  AWS WAF v2 WebACL (scope = CLOUDFRONT → us-east-1)
###############################################################################

resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-waf-${var.environment}"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # ── Rule 1: AWS Managed – Core Rule Set ────────────────────────────────────
  rule {
    name     = "AWS-AWSManagedRulesCoreRuleSet"
    priority = 1

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCoreRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-core-rules-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 2: AWS Managed – Known Bad Inputs ─────────────────────────────────
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-bad-inputs-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 3: AWS Managed – SQL Injection ───────────────────────────────────
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-sqli-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 4: Custom Rate Limiting ──────────────────────────────────────────
  rule {
    name     = "RateLimitRule"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  # ── Rule 5: AWS Managed – IP Reputation List ──────────────────────────────
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 5

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-ip-reputation-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-${var.environment}"
    sampled_requests_enabled   = true
  }

  tags = { Name = "${var.project_name}-waf-${var.environment}" }
}
