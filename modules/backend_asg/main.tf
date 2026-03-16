###############################################################################
# modules/backend_asg/main.tf  –  Backend Auto Scaling Group
#   Runs Spring Boot app jar fetched from S3; CloudWatch Agent ships logs
###############################################################################

locals {
  name_prefix = "${var.project_name}-backend-${var.environment}"
}

# ── User Data ─────────────────────────────────────────────────────────────────
data "template_file" "user_data" {
  template = <<-EOF
    #!/bin/bash
    set -eux

    yum update -y
    yum install -y amazon-cloudwatch-agent awscli java-17-amazon-corretto

    # Pull Spring Boot fat jar from S3
    mkdir -p /opt/springboot/backend
    aws s3 cp s3://${var.s3_bucket_name}/backend-app.jar /opt/springboot/backend/app.jar

    # Write application.properties with RDS connection
    mkdir -p /opt/springboot/backend/config
    cat > /opt/springboot/backend/config/application.properties <<PROPS
    server.port=${var.backend_app_port}
    spring.datasource.url=jdbc:mysql://${var.db_endpoint}/${var.db_name}?useSSL=true&requireSSL=true
    spring.datasource.username=${var.db_username}
    spring.datasource.password=${var.db_password}
    spring.jpa.hibernate.ddl-auto=update
    spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MySQL8Dialect
    PROPS

    # SystemD service
    cat > /etc/systemd/system/backend-app.service <<UNIT
    [Unit]
    Description=Spring Boot Backend Application
    After=network.target

    [Service]
    Type=simple
    User=ec2-user
    WorkingDirectory=/opt/springboot/backend
    ExecStart=/usr/bin/java -jar /opt/springboot/backend/app.jar \
      --spring.config.location=file:/opt/springboot/backend/config/application.properties
    Restart=always
    RestartSec=10
    StandardOutput=journal
    StandardError=journal
    SyslogIdentifier=backend-app

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable backend-app
    systemctl start  backend-app

    # CloudWatch Agent – ship app logs + system logs
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
              },
              {
                "file_path": "/var/log/springboot/*.log",
                "log_group_name": "${var.log_group_name}",
                "log_stream_name": "{instance_id}/application"
              }
            ]
          }
        }
      },
      "metrics": {
        "metrics_collected": {
          "cpu": { "measurement": ["cpu_usage_active"], "metrics_collection_interval": 60 },
          "mem": { "measurement": ["mem_used_percent"], "metrics_collection_interval": 60 }
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
resource "aws_launch_template" "backend" {
  name_prefix   = "${local.name_prefix}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name != "" ? var.key_pair_name : null

  iam_instance_profile { name = var.instance_profile }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.sg_id]
  }

  user_data = base64encode(data.template_file.user_data.rendered)

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring { enabled = true }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${local.name_prefix}-instance", Tier = "backend" }
  }

  lifecycle { create_before_destroy = true }
}

# ── Auto Scaling Group ────────────────────────────────────────────────────────
resource "aws_autoscaling_group" "backend" {
  name                      = "${local.name_prefix}-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [var.nlb_target_group_arn]
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  # Lifecycle Hook – wait for in-flight requests to drain
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
      instance_warmup        = 180
    }
  }

  dynamic "tag" {
    for_each = {
      Name        = "${local.name_prefix}-instance"
      Environment = var.environment
      Tier        = "backend"
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
  autoscaling_group_name = aws_autoscaling_group.backend.name
  desired_capacity       = var.desired_capacity
  min_size               = var.min_size
  max_size               = var.max_size
  recurrence             = var.scale_out_cron
  time_zone              = "UTC"
}

resource "aws_autoscaling_schedule" "scale_in" {
  scheduled_action_name  = "${local.name_prefix}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  desired_capacity       = 0
  min_size               = 0
  max_size               = var.max_size
  recurrence             = var.scale_in_cron
  time_zone              = "UTC"
}

# ── CPU-based Dynamic Scaling ─────────────────────────────────────────────────
resource "aws_autoscaling_policy" "cpu_tracking" {
  name                   = "${local.name_prefix}-cpu-tracking"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}
