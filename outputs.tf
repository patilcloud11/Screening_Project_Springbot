###############################################################################
# outputs.tf  –  Root-level outputs exposed after apply
###############################################################################

# ─────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────
output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets (frontend/backend EC2)"
  value       = module.vpc.private_subnet_ids
}

output "db_subnet_ids" {
  description = "IDs of isolated DB subnets"
  value       = module.vpc.db_subnet_ids
}

# ─────────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────────
output "alb_sg_id" {
  description = "Security Group ID – Application Load Balancer"
  value       = module.security_groups.alb_sg_id
}

output "frontend_sg_id" {
  description = "Security Group ID – Frontend ASG instances"
  value       = module.security_groups.frontend_sg_id
}

output "backend_sg_id" {
  description = "Security Group ID – Backend ASG instances"
  value       = module.security_groups.backend_sg_id
}

output "rds_sg_id" {
  description = "Security Group ID – RDS"
  value       = module.security_groups.rds_sg_id
}

# ─────────────────────────────────────────────
# ALB
# ─────────────────────────────────────────────
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "frontend_target_group_arn" {
  description = "ARN of the ALB frontend target group"
  value       = module.alb.frontend_tg_arn
}

# ─────────────────────────────────────────────
# NLB
# ─────────────────────────────────────────────
output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer (internal)"
  value       = module.nlb.nlb_dns_name
}

# ─────────────────────────────────────────────
# CloudFront
# ─────────────────────────────────────────────
output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}

# ─────────────────────────────────────────────
# RDS
# ─────────────────────────────────────────────
output "rds_endpoint" {
  description = "RDS instance endpoint (host:port)"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS port"
  value       = module.rds.db_port
}

# ─────────────────────────────────────────────
# S3
# ─────────────────────────────────────────────
output "frontend_s3_bucket_name" {
  description = "Name of the frontend S3 bucket"
  value       = module.s3.frontend_bucket_name
}

output "backend_s3_bucket_name" {
  description = "Name of the backend S3 bucket"
  value       = module.s3.backend_bucket_name
}

output "frontend_s3_bucket_arn" {
  description = "ARN of the frontend S3 bucket"
  value       = module.s3.frontend_bucket_arn
}

output "backend_s3_bucket_arn" {
  description = "ARN of the backend S3 bucket"
  value       = module.s3.backend_bucket_arn
}

# ─────────────────────────────────────────────
# CloudWatch
# ─────────────────────────────────────────────
output "frontend_log_group_name" {
  description = "CloudWatch log group for frontend instances"
  value       = module.cloudwatch.frontend_log_group_name
}

output "backend_log_group_name" {
  description = "CloudWatch log group for backend instances"
  value       = module.cloudwatch.backend_log_group_name
}

# ─────────────────────────────────────────────
# SNS
# ─────────────────────────────────────────────
output "sns_topic_arn" {
  description = "ARN of the SNS alarm topic"
  value       = module.sns.topic_arn
}

# ─────────────────────────────────────────────
# Lambda
# ─────────────────────────────────────────────
output "lambda_function_name" {
  description = "Name of the Slack-notification Lambda"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Slack-notification Lambda"
  value       = module.lambda.function_arn
}

# ─────────────────────────────────────────────
# ACM
# ─────────────────────────────────────────────
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate (us-east-1)"
  value       = module.acm.certificate_arn
}

# ─────────────────────────────────────────────
# ASG names
# ─────────────────────────────────────────────
output "frontend_asg_name" {
  description = "Name of the frontend Auto Scaling Group"
  value       = module.frontend_asg.asg_name
}

output "backend_asg_name" {
  description = "Name of the backend Auto Scaling Group"
  value       = module.backend_asg.asg_name
}
