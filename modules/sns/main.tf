###############################################################################
# modules/sns/main.tf  –  SNS topic for CloudWatch alarm fan-out
###############################################################################

resource "aws_sns_topic" "alarms" {
  name         = "${var.project_name}-alarms-${var.environment}"
  display_name = "${var.project_name} Alarms (${var.environment})"
  tags         = { Name = "${var.project_name}-alarms-${var.environment}" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
