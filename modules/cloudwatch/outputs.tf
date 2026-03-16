output "frontend_log_group_name" { value = aws_cloudwatch_log_group.frontend.name }
output "backend_log_group_name"  { value = aws_cloudwatch_log_group.backend.name }
output "rds_log_group_name"      { value = aws_cloudwatch_log_group.rds.name }
output "dashboard_name"          { value = aws_cloudwatch_dashboard.main.dashboard_name }
