variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_security_group_id" {
  description = "Only this security group is allowed to reach RDS"
  type        = string
}

variable "engine" {
  description = "postgres or mysql"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appadmin"
}

variable "db_password" {
  description = "Pass via TF_VAR_db_password or a secrets manager in real usage - never commit this"
  type        = string
  sensitive   = true
}

variable "backup_retention_period" {
  description = "Days to retain automated backups. dev=short, prod=long"
  type        = number
  default     = 3
}

variable "deletion_protection" {
  description = "dev=false, prod=true"
  type        = bool
  default     = false
}

variable "multi_az" {
  description = "prod should be true for HA"
  type        = bool
  default     = false
}
