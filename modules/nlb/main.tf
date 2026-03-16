###############################################################################
# modules/nlb/main.tf  –  Internal Network Load Balancer (ALB → NLB → Backend)
###############################################################################

resource "aws_lb" "main" {
  name               = "${var.project_name}-nlb-${var.environment}"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids

  enable_cross_zone_load_balancing = true

  tags = { Name = "${var.project_name}-nlb-${var.environment}" }
}

resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-be-tg-${var.environment}"
  port        = var.backend_app_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = var.backend_app_port
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = { Name = "${var.project_name}-be-tg-${var.environment}" }
}

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.backend_app_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
