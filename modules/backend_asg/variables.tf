variable "project_name"         { type = string }
variable "environment"          { type = string }
variable "vpc_id"               { type = string }
variable "private_subnet_ids"   { type = list(string) }
variable "sg_id"                { type = string }
variable "instance_profile"     { type = string }
variable "ami_id"               { type = string }
variable "instance_type"        { type = string }
variable "key_pair_name"        { type = string }
variable "nlb_target_group_arn" { type = string }
variable "min_size"             { type = number }
variable "max_size"             { type = number }
variable "desired_capacity"     { type = number }
variable "scale_out_cron"       { type = string }
variable "scale_in_cron"        { type = string }
variable "s3_bucket_name"       { type = string }
variable "db_endpoint"          { type = string }
variable "db_name"              { type = string }
variable "db_username" {
  type      = string
  sensitive = true
}
variable "db_password" {
  type      = string
  sensitive = true
}
variable "backend_app_port" { type = number }
variable "log_group_name"   { type = string }
