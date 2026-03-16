variable "project_name"    { type = string }
variable "environment"     { type = string }
variable "sns_topic_arn"   { type = string }
variable "lambda_role_arn" { type = string }
variable "slack_webhook_url" {
  type      = string
  sensitive = true
}
variable "slack_channel" { type = string }
