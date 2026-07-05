terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "../../modules/network"

  env                  = "prod"
  vpc_cidr             = "10.1.0.0/16"
  azs                  = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
  single_nat_gateway   = false
}

module "ecs" {
  source = "../../modules/ecs"

  env                = "prod"
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids

  container_image = "public.ecr.aws/nginx/nginx:latest"
  task_cpu        = "1024"
  task_memory     = "2048"
  desired_count   = 3

  db_host = module.rds.endpoint
  db_name = module.rds.db_name
}

module "rds" {
  source = "../../modules/rds"

  env                   = "prod"
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  ecs_security_group_id = module.ecs.ecs_security_group_id

  engine            = "postgres"
  instance_class    = "db.r6g.large"
  allocated_storage = 100

  db_name     = "appdb_prod"
  db_username = "appadmin"
  db_password = var.db_password

  backup_retention_period = 30
  deletion_protection     = true
  multi_az                = true
}
