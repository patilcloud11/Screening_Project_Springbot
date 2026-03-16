###############################################################################
# modules/frontend_asg/main.tf  –  Frontend Auto Scaling Group
#   Runs FE Linux Service + systemd-managed Spring Boot front-end process
###############################################################################

locals {
  name_prefix = "${var.project_name}-frontend-${var.environment}"
}

# ── User Data (bootstraps FE Linux Service + SystemD) ─────────────────────────
data "template_file" "user_data" {
  template = <<-EOF
    #!/bin/bash
    set -eux

    # System update
    yum update -y
    yum install -y amazon-cloudwatch-agent awscli java-17-amazon-corretto

    # Pull app artifact from S3
    mkdir -p /opt/springboot/frontend
    aws s3 cp s3://${var.s3_bucket_name}/frontend-app.jar /opt/springboot/frontend/app.jar

    # Create systemd service
    cat > /etc/systemd/system/frontend-app.service <<UNIT
    [Unit]
    Description=Spring Boot Frontend Application
    After=network.target

    [Service]
    Type=simple
    User=ec2-user
    WorkingDirectory=/opt/springboot/frontend
    ExecStart=/usr/bin/java -jar /opt/springboot/frontend/app.jar --server.port=80
    Restart=always
    RestartSec=10
    StandardOutput=journal
    StandardError=journal
    SyslogIdentifier=frontend-app

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable frontend-app
    systemctl start  frontend-app

    # CloudWatch Agent config
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<CWA
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/messages",
                "log_group_name": "${var.log_group_name}",
                "log_stream_name": "{instance_id}/messages"
              }
            ]
          }
        }
      }
    }
    CWA

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 \
      -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  EOF
}

# ── Launch Template ───────────────────────────────────────────────────────────
resource "aws_launch_template" "frontend" {
  name_prefix   = "${local.name_prefix}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name != "" ? var.key_pair_name : null

  iam_instance_profile {
    name = var.instance_profile
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.sg_id]
  }

  user_data = base64encode(data.template_file.user_data.rendered)

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"   # IMDSv2
    http_put_response_hop_limit = 1
  }

  monitoring { enabled = true }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${local.name_prefix}-instance", Tier = "frontend" }
  }

  lifecycle { create_before_destroy = true }
}

# ── Auto Scaling Group ────────────────────────────────────────────────────────
resource "aws_autoscaling_group" "frontend" {
  name                      = "${local.name_prefix}-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [var.alb_target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  # Lifecycle Hook – drains connection before termination
  initial_lifecycle_hook {
    name                 = "${local.name_prefix}-termination-hook"
    default_result       = "CONTINUE"
    heartbeat_timeout    = 300
    lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
  }

  dynamic "tag" {
    for_each = {
      Name        = "${local.name_prefix}-instance"
      Environment = var.environment
      Tier        = "frontend"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# ── Scheduled Scaling (Cost Cutting) ─────────────────────────────────────────
resource "aws_autoscaling_schedule" "scale_out" {
  scheduled_action_name  = "${local.name_prefix}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.frontend.name
  desired_capacity       = var.desired_capacity
  min_size               = var.min_size
  max_size               = var.max_size
  recurrence             = var.scale_out_cron
  time_zone              = "UTC"
}

resource "aws_autoscaling_schedule" "scale_in" {
  scheduled_action_name  = "${local.name_prefix}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.frontend.name
  desired_capacity       = 0
  min_size               = 0
  max_size               = var.max_size
  recurrence             = var.scale_in_cron
  time_zone              = "UTC"
}

# ── CPU-based Dynamic Scaling Policy ─────────────────────────────────────────
resource "aws_autoscaling_policy" "cpu_tracking" {
  name                   = "${local.name_prefix}-cpu-tracking"
  autoscaling_group_name = aws_autoscaling_group.frontend.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}
