output "db_endpoint" {
  value     = aws_db_instance.main.endpoint
  sensitive = true
}
output "db_port"              { value = aws_db_instance.main.port }
output "db_identifier"        { value = aws_db_instance.main.identifier }
output "db_subnet_group_name" { value = aws_db_subnet_group.main.name }
