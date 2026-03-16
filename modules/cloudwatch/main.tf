###############################################################################
# modules/cloudwatch/main.tf  –  Log Groups, Metric Filters, CW Alarms
###############################################################################

# ── Log Groups ────────────────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/aws/${var.project_name}/${var.environment}/frontend"
  retention_in_days = var.log_retention_days
  tags              = { Name = "${var.project_name}-frontend-logs-${var.environment}" }
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/aws/${var.project_name}/${var.environment}/backend"
  retention_in_days = var.log_retention_days
  tags              = { Name = "${var.project_name}-backend-logs-${var.environment}" }
}

resource "aws_cloudwatch_log_group" "rds" {
  name              = "/aws/rds/instance/${var.rds_identifier}/slowquery"
  retention_in_days = var.log_retention_days
  tags              = { Name = "${var.project_name}-rds-logs-${var.environment}" }
}

# ── Metric Filters ────────────────────────────────────────────────────────────
resource "aws_cloudwatch_log_metric_filter" "backend_errors" {
  name           = "${var.project_name}-backend-errors-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.backend.name
  pattern        = "[timestamp, level=ERROR, ...]"

  metric_transformation {
    name      = "BackendErrorCount"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "backend_5xx" {
  name           = "${var.project_name}-backend-5xx-${var.environment}"
  log_group_name = aws_cloudwatch_log_group.backend.name
  pattern        = "[timestamp, level, logger, thread, msg=\"*5[0-9][0-9]*\", ...]"

  metric_transformation {
    name      = "Backend5xxCount"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
    default_value = "0"
  }
}

# ── CPU Alarms ────────────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "frontend_cpu_high" {
  alarm_name          = "${var.project_name}-frontend-cpu-high-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "Frontend ASG CPU is too high"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = { AutoScalingGroupName = var.frontend_asg_name }
}

resource "aws_cloudwatch_metric_alarm" "backend_cpu_high" {
  alarm_name          = "${var.project_name}-backend-cpu-high-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "Backend ASG CPU is too high"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = { AutoScalingGroupName = var.backend_asg_name }
}

# ── RDS Alarms ────────────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.project_name}-rds-cpu-high-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "RDS CPU utilisation is too high"
  alarm_actions       = [var.sns_topic_arn]
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  alarm_name          = "${var.project_name}-rds-storage-low-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120  # 5 GB
  alarm_description   = "RDS free storage below 5 GB"
  alarm_actions       = [var.sns_topic_arn]
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${var.project_name}-rds-connections-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "RDS connection count high"
  alarm_actions       = [var.sns_topic_arn]
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
}

# ── Application Error Alarm ───────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "backend_errors" {
  alarm_name          = "${var.project_name}-backend-app-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BackendErrorCount"
  namespace           = "${var.project_name}/${var.environment}"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_description   = "Too many ERROR log entries in backend"
  alarm_actions       = [var.sns_topic_arn]
}

# ── Dashboard ─────────────────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "Frontend CPU"
          metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.frontend_asg_name]]
          period = 300
          stat   = "Average"
        }
      },
      {
        type = "metric"
        properties = {
          title  = "Backend CPU"
          metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.backend_asg_name]]
          period = 300
          stat   = "Average"
        }
      },
      {
        type = "metric"
        properties = {
          title  = "RDS CPU & Connections"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_identifier],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_identifier]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type = "log"
        properties = {
          title   = "Backend Error Logs"
          query   = "SOURCE '${aws_cloudwatch_log_group.backend.name}' | filter level = 'ERROR' | stats count() by bin(5m)"
          region  = "ap-south-1"
          view    = "timeSeries"
        }
      }
    ]
  })
}
