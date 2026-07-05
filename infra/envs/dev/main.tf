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

  env                  = "dev"
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["ap-south-1a", "ap-south-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  single_nat_gateway   = true
}

module "ecs" {
  source = "../../modules/ecs"

  env                = "dev"
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids

  container_image = "public.ecr.aws/nginx/nginx:latest"
  task_cpu        = "256"
  task_memory     = "512"
  desired_count   = 1

  db_host = module.rds.endpoint
  db_name = module.rds.db_name
}

module "rds" {
  source = "../../modules/rds"

  env                   = "dev"
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  ecs_security_group_id = module.ecs.ecs_security_group_id

  engine            = "postgres"
  instance_class    = "db.t4g.micro"
  allocated_storage = 20

  db_name     = "appdb_dev"
  db_username = "appadmin"
  db_password = var.db_password

  backup_retention_period = 1
  deletion_protection     = false
  multi_az                = false
}
