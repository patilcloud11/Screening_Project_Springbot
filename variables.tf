# ─────────────────────────────────────────────
# General
# ─────────────────────────────────────────────
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "springboot-app"
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "owner" {
  description = "Owner / team responsible for this infrastructure"
  type        = string
  default     = "platform-team"
}

# ─────────────────────────────────────────────
# VPC & Networking
# ─────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to use (at least 2)"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets – frontend/backend EC2"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "db_subnet_cidrs" {
  description = "CIDRs for isolated DB subnets"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cost saving for non-prod)"
  type        = bool
  default     = false
}

# ─────────────────────────────────────────────
# DNS / ACM / CloudFront
# ─────────────────────────────────────────────
variable "domain_name" {
  description = "Primary domain name (managed via GoDaddy / Route53)"
  type        = string
  default     = "example.com"
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate (us-east-1) for CloudFront"
  type        = string
  default     = ""
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_200"
}

variable "waf_rate_limit" {
  description = "Max requests per 5 min per IP for WAF rate-limit rule"
  type        = number
  default     = 2000
}

# ─────────────────────────────────────────────
# Application Load Balancer
# ─────────────────────────────────────────────
variable "alb_deletion_protection" {
  description = "Enable ALB deletion protection"
  type        = bool
  default     = false
}

variable "alb_idle_timeout" {
  description = "ALB idle connection timeout in seconds"
  type        = number
  default     = 60
}

# ─────────────────────────────────────────────
# Frontend ASG
# ─────────────────────────────────────────────
variable "frontend_ami_id" {
  description = "AMI ID for frontend EC2 instances"
  type        = string
}

variable "frontend_instance_type" {
  description = "EC2 instance type for frontend"
  type        = string
  default     = "t3.small"
}

variable "frontend_min_size" {
  description = "Minimum number of frontend instances"
  type        = number
  default     = 1
}

variable "frontend_max_size" {
  description = "Maximum number of frontend instances"
  type        = number
  default     = 4
}

variable "frontend_desired_capacity" {
  description = "Desired number of frontend instances"
  type        = number
  default     = 2
}

variable "frontend_scale_out_cron" {
  description = "Cron expression to scale OUT frontend (UTC)"
  type        = string
  default     = "0 2 * * MON-FRI"
}

variable "frontend_scale_in_cron" {
  description = "Cron expression to scale IN frontend (UTC)"
  type        = string
  default     = "0 20 * * MON-FRI"
}

variable "frontend_s3_bucket" {
  description = "S3 bucket name for frontend static assets"
  type        = string
  default     = ""
}

# ─────────────────────────────────────────────
# Backend ASG
# ─────────────────────────────────────────────
variable "backend_ami_id" {
  description = "AMI ID for backend EC2 instances (Spring Boot)"
  type        = string
}

variable "backend_instance_type" {
  description = "EC2 instance type for backend"
  type        = string
  default     = "t3.medium"
}

variable "backend_min_size" {
  description = "Minimum number of backend instances"
  type        = number
  default     = 1
}

variable "backend_max_size" {
  description = "Maximum number of backend instances"
  type        = number
  default     = 4
}

variable "backend_desired_capacity" {
  description = "Desired number of backend instances"
  type        = number
  default     = 2
}

variable "backend_scale_out_cron" {
  description = "Cron expression to scale OUT backend (UTC)"
  type        = string
  default     = "0 2 * * MON-FRI"
}

variable "backend_scale_in_cron" {
  description = "Cron expression to scale IN backend (UTC)"
  type        = string
  default     = "0 20 * * MON-FRI"
}

variable "backend_app_port" {
  description = "Port Spring Boot app listens on"
  type        = number
  default     = 8080
}

variable "backend_s3_bucket" {
  description = "S3 bucket name for backend app data / artifacts"
  type        = string
  default     = ""
}

# ─────────────────────────────────────────────
# RDS
# ─────────────────────────────────────────────
variable "db_engine" {
  description = "RDS engine type"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Max storage autoscaling in GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "springbootdb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_multi_az" {
  description = "Enable Multi-AZ RDS deployment"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Days to retain automated backups"
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Enable RDS deletion protection"
  type        = bool
  default     = false
}

# ─────────────────────────────────────────────
# S3
# ─────────────────────────────────────────────
variable "s3_force_destroy" {
  description = "Allow destroying non-empty S3 buckets"
  type        = bool
  default     = false
}

variable "s3_versioning_enabled" {
  description = "Enable S3 versioning on app data buckets"
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────
# CloudWatch & Alerting
# ─────────────────────────────────────────────
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "alarm_email" {
  description = "Email address for SNS alarm notifications"
  type        = string
  default     = "ops@example.com"
}

variable "cpu_alarm_threshold" {
  description = "CPU utilisation % to trigger alarm"
  type        = number
  default     = 80
}

# ─────────────────────────────────────────────
# Lambda / Slack
# ─────────────────────────────────────────────
variable "slack_webhook_url" {
  description = "Slack incoming webhook URL for alarm notifications"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_channel" {
  description = "Slack channel name for notifications"
  type        = string
  default     = "#alerts"
}

# ─────────────────────────────────────────────
# Key Pair
# ─────────────────────────────────────────────
variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = ""
}
