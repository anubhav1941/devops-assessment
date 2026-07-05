variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "db_password" {
  description = "Set via TF_VAR_db_password env var, never hardcode or commit"
  type        = string
  sensitive   = true
}
