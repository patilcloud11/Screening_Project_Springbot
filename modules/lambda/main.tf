###############################################################################
# modules/lambda/main.tf  –  SNS → Slack notification relay
###############################################################################

locals {
  function_name = "${var.project_name}-slack-notify-${var.environment}"
  handler_file  = "${path.module}/src/handler.py"
  archive_path  = "${path.module}/slack_notify.zip"
}

# ── Inline Python source ──────────────────────────────────────────────────────
resource "local_file" "handler" {
  filename = local.handler_file
  content  = <<-PYTHON
    import json
    import os
    import urllib.request

    WEBHOOK_URL = os.environ["SLACK_WEBHOOK_URL"]
    CHANNEL     = os.environ.get("SLACK_CHANNEL", "#alerts")

    def lambda_handler(event, context):
        for record in event.get("Records", []):
            sns_message = record["Sns"]["Message"]
            subject     = record["Sns"].get("Subject", "AWS CloudWatch Alarm")

            try:
                msg_dict = json.loads(sns_message)
                alarm_name  = msg_dict.get("AlarmName", subject)
                state       = msg_dict.get("NewStateValue", "UNKNOWN")
                reason      = msg_dict.get("NewStateReason", sns_message)
                color       = "#FF0000" if state == "ALARM" else "#36A64F"

                payload = {
                    "channel": CHANNEL,
                    "attachments": [{
                        "color": color,
                        "title": f":bell: {alarm_name}",
                        "fields": [
                            {"title": "State",  "value": state,  "short": True},
                            {"title": "Reason", "value": reason, "short": False},
                        ],
                    }]
                }
            except (json.JSONDecodeError, KeyError):
                payload = {
                    "channel": CHANNEL,
                    "text": f":bell: *{subject}*\n{sns_message}"
                }

            data = json.dumps(payload).encode("utf-8")
            req  = urllib.request.Request(
                WEBHOOK_URL,
                data=data,
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                print(f"Slack response: {resp.status}")

        return {"statusCode": 200}
  PYTHON
}

# ── Zip the source ────────────────────────────────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = local_file.handler.filename
  output_path = local.archive_path
}

# ── Lambda Function ───────────────────────────────────────────────────────────
resource "aws_lambda_function" "slack_notify" {
  function_name    = local.function_name
  role             = var.lambda_role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      SLACK_CHANNEL     = var.slack_channel
    }
  }

  tags = { Name = local.function_name }
}

# ── CloudWatch Log Group for Lambda ──────────────────────────────────────────
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 7
}

# ── SNS → Lambda Subscription ────────────────────────────────────────────────
resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notify.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notify.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn
}
