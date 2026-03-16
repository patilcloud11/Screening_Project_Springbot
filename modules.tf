###############################################################################
# modules.tf  –  Wires together every child module for the three-tier
#                Spring Boot application architecture
###############################################################################

# ─────────────────────────────────────────────
# 1. VPC & Networking
# ─────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
}

# ─────────────────────────────────────────────
# 2. Security Groups
# ─────────────────────────────────────────────
module "security_groups" {
  source = "./modules/security_groups"

  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  vpc_cidr         = var.vpc_cidr
  backend_app_port = var.backend_app_port
}

# ─────────────────────────────────────────────
# 3. IAM Roles & Policies
# ─────────────────────────────────────────────
module "iam" {
  source = "./modules/iam"

  project_name       = var.project_name
  environment        = var.environment
  frontend_s3_bucket = module.s3.frontend_bucket_arn
  backend_s3_bucket  = module.s3.backend_bucket_arn

  depends_on = [module.s3]
}

# ─────────────────────────────────────────────
# 4. ACM Certificate  (us-east-1 for CloudFront)
# ─────────────────────────────────────────────
module "acm" {
  source = "./modules/acm"
  providers = {
    aws = aws.us_east_1
  }

  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name
}

# ─────────────────────────────────────────────
# 5. WAF WebACL
# ─────────────────────────────────────────────
module "waf" {
  source = "./modules/waf"
  providers = {
    aws = aws.us_east_1
  }

  project_name   = var.project_name
  environment    = var.environment
  waf_rate_limit = var.waf_rate_limit
}

# ─────────────────────────────────────────────
# 6. S3 Buckets  (frontend assets + backend app data)
# ─────────────────────────────────────────────
module "s3" {
  source = "./modules/s3"

  project_name          = var.project_name
  environment           = var.environment
  frontend_bucket_name  = var.frontend_s3_bucket != "" ? var.frontend_s3_bucket : "${var.project_name}-frontend-${var.environment}"
  backend_bucket_name   = var.backend_s3_bucket != "" ? var.backend_s3_bucket : "${var.project_name}-backend-${var.environment}"
  force_destroy         = var.s3_force_destroy
  versioning_enabled    = var.s3_versioning_enabled
}

# ─────────────────────────────────────────────
# 7. Application Load Balancer  (internet-facing)
# ─────────────────────────────────────────────
module "alb" {
  source = "./modules/alb"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  alb_sg_id           = module.security_groups.alb_sg_id
  acm_certificate_arn = module.acm.certificate_arn
  deletion_protection = var.alb_deletion_protection
  idle_timeout        = var.alb_idle_timeout

  depends_on = [module.vpc, module.security_groups, module.acm]
}

# ─────────────────────────────────────────────
# 8. Frontend ASG  (FE Linux Service + System D)
# ─────────────────────────────────────────────
module "frontend_asg" {
  source = "./modules/frontend_asg"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  sg_id             = module.security_groups.frontend_sg_id
  instance_profile  = module.iam.frontend_instance_profile_name
  ami_id            = var.frontend_ami_id
  instance_type     = var.frontend_instance_type
  key_pair_name     = var.key_pair_name
  alb_target_group_arn = module.alb.frontend_tg_arn
  min_size          = var.frontend_min_size
  max_size          = var.frontend_max_size
  desired_capacity  = var.frontend_desired_capacity
  scale_out_cron    = var.frontend_scale_out_cron
  scale_in_cron     = var.frontend_scale_in_cron
  s3_bucket_name    = module.s3.frontend_bucket_name
  log_group_name    = module.cloudwatch.frontend_log_group_name

  depends_on = [module.alb, module.iam, module.s3, module.cloudwatch]
}

# ─────────────────────────────────────────────
# 9. Network Load Balancer  (internal, ALB → NLB → Backend)
# ─────────────────────────────────────────────
module "nlb" {
  source = "./modules/nlb"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  backend_app_port   = var.backend_app_port

  depends_on = [module.vpc]
}

# ─────────────────────────────────────────────
# 10. Backend ASG  (Spring Boot application)
# ─────────────────────────────────────────────
module "backend_asg" {
  source = "./modules/backend_asg"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  sg_id              = module.security_groups.backend_sg_id
  instance_profile   = module.iam.backend_instance_profile_name
  ami_id             = var.backend_ami_id
  instance_type      = var.backend_instance_type
  key_pair_name      = var.key_pair_name
  nlb_target_group_arn = module.nlb.backend_tg_arn
  min_size           = var.backend_min_size
  max_size           = var.backend_max_size
  desired_capacity   = var.backend_desired_capacity
  scale_out_cron     = var.backend_scale_out_cron
  scale_in_cron      = var.backend_scale_in_cron
  s3_bucket_name     = module.s3.backend_bucket_name
  db_endpoint        = module.rds.db_endpoint
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  backend_app_port   = var.backend_app_port
  log_group_name     = module.cloudwatch.backend_log_group_name

  depends_on = [module.nlb, module.rds, module.iam, module.s3, module.cloudwatch]
}

# ─────────────────────────────────────────────
# 11. RDS  (Amazon RDS – MySQL)
# ─────────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  project_name             = var.project_name
  environment              = var.environment
  db_subnet_ids            = module.vpc.db_subnet_ids
  rds_sg_id                = module.security_groups.rds_sg_id
  db_engine                = var.db_engine
  db_engine_version        = var.db_engine_version
  db_instance_class        = var.db_instance_class
  db_allocated_storage     = var.db_allocated_storage
  db_max_allocated_storage = var.db_max_allocated_storage
  db_name                  = var.db_name
  db_username              = var.db_username
  db_password              = var.db_password
  multi_az                 = var.db_multi_az
  backup_retention_period  = var.db_backup_retention_period
  deletion_protection      = var.db_deletion_protection

  depends_on = [module.vpc, module.security_groups]
}

# ─────────────────────────────────────────────
# 12. CloudWatch  (Log Groups, Metric Filters, Alarms)
# ─────────────────────────────────────────────
module "cloudwatch" {
  source = "./modules/cloudwatch"

  project_name        = var.project_name
  environment         = var.environment
  log_retention_days  = var.log_retention_days
  sns_topic_arn       = module.sns.topic_arn
  cpu_alarm_threshold = var.cpu_alarm_threshold
  frontend_asg_name   = "${var.project_name}-frontend-asg-${var.environment}"
  backend_asg_name    = "${var.project_name}-backend-asg-${var.environment}"
  rds_identifier      = "${var.project_name}-rds-${var.environment}"

  depends_on = [module.sns]
}

# ─────────────────────────────────────────────
# 13. SNS  (alarm fan-out to email + Lambda/Slack)
# ─────────────────────────────────────────────
module "sns" {
  source = "./modules/sns"

  project_name = var.project_name
  environment  = var.environment
  alarm_email  = var.alarm_email
}

# ─────────────────────────────────────────────
# 14. Lambda  (SNS → Slack notification relay)
# ─────────────────────────────────────────────
module "lambda" {
  source = "./modules/lambda"

  project_name      = var.project_name
  environment       = var.environment
  sns_topic_arn     = module.sns.topic_arn
  lambda_role_arn   = module.iam.lambda_role_arn
  slack_webhook_url = var.slack_webhook_url
  slack_channel     = var.slack_channel

  depends_on = [module.sns, module.iam]
}

# ─────────────────────────────────────────────
# 15. CloudFront  (CDN + WAF + ACM)
# ─────────────────────────────────────────────
module "cloudfront" {
  source = "./modules/cloudfront"

  project_name        = var.project_name
  environment         = var.environment
  domain_name         = var.domain_name
  acm_certificate_arn = module.acm.certificate_arn
  waf_web_acl_arn     = module.waf.web_acl_arn
  alb_dns_name        = module.alb.alb_dns_name
  s3_frontend_bucket  = module.s3.frontend_bucket_regional_domain
  price_class         = var.cloudfront_price_class

  depends_on = [module.acm, module.waf, module.alb, module.s3]
}
