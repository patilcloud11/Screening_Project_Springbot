variable "project_name"        { type = string }
variable "environment"         { type = string }
variable "log_retention_days"  { type = number }
variable "sns_topic_arn"       { type = string }
variable "cpu_alarm_threshold" { type = number }
variable "frontend_asg_name"   { type = string }
variable "backend_asg_name"    { type = string }
variable "rds_identifier"      { type = string }
