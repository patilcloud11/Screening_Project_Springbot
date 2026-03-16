variable "project_name"             { type = string }
variable "environment"              { type = string }
variable "db_subnet_ids"            { type = list(string) }
variable "rds_sg_id"                { type = string }
variable "db_engine"                { type = string }
variable "db_engine_version"        { type = string }
variable "db_instance_class"        { type = string }
variable "db_allocated_storage"     { type = number }
variable "db_max_allocated_storage" { type = number }
variable "db_name"                  { type = string }
variable "db_username" {
  type      = string
  sensitive = true
}
variable "db_password" {
  type      = string
  sensitive = true
}
variable "multi_az"                 { type = bool }
variable "backup_retention_period"  { type = number }
variable "deletion_protection"      { type = bool }
