output "alb_arn"         { value = aws_lb.main.arn }
output "alb_dns_name"    { value = aws_lb.main.dns_name }
output "alb_zone_id"     { value = aws_lb.main.zone_id }
output "frontend_tg_arn" { value = aws_lb_target_group.frontend.arn }
output "https_listener_arn" { value = aws_lb_listener.https.arn }
