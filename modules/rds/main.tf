###############################################################################
# modules/rds/main.tf  –  Amazon RDS (MySQL) with DB Subnet Group
###############################################################################

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-grp-${var.environment}"
  subnet_ids = var.db_subnet_ids

  tags = { Name = "${var.project_name}-db-subnet-grp-${var.environment}" }
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-db-params-${var.environment}"
  family = "${var.db_engine}${split(".", var.db_engine_version)[0]}"

  parameter {
    name  = "slow_query_log"
    value = "1"
  }
  parameter {
    name  = "long_query_time"
    value = "2"
  }
  parameter {
    name  = "log_output"
    value = "FILE"
  }

  tags = { Name = "${var.project_name}-db-params-${var.environment}" }

  lifecycle { create_before_destroy = true }
}

resource "aws_db_instance" "main" {
  identifier             = "${var.project_name}-rds-${var.environment}"
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = var.db_max_allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az               = var.multi_az
  publicly_accessible    = false

  backup_retention_period  = var.backup_retention_period
  backup_window            = "03:00-04:00"
  maintenance_window       = "Mon:04:00-Mon:05:00"
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot    = true

  deletion_protection      = var.deletion_protection
  skip_final_snapshot      = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.project_name}-rds-final-${var.environment}" : null

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  tags = { Name = "${var.project_name}-rds-${var.environment}" }
}
