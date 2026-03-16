variable "project_name"        { type = string }
variable "environment"         { type = string }
variable "domain_name"         { type = string }
variable "acm_certificate_arn" { type = string }
variable "waf_web_acl_arn"     { type = string }
variable "alb_dns_name"        { type = string }
variable "s3_frontend_bucket"  { type = string }
variable "price_class"         { type = string }
