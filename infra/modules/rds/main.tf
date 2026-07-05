locals {
  name = "${var.env}-app"
  port = var.engine == "mysql" ? 3306 : 5432
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "Allow DB traffic only from ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "DB access from ECS tasks only"
    from_port       = local.port
    to_port         = local.port
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-rds-sg"
    Env  = var.env
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${local.name}-rds-subnet-group"
    Env  = var.env
  }
}

resource "aws_db_instance" "this" {
  identifier     = "${local.name}-db"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 3
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = local.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  backup_retention_period   = var.backup_retention_period
  deletion_protection       = var.deletion_protection
  multi_az                  = var.multi_az
  skip_final_snapshot       = var.env == "prod" ? false : true
  final_snapshot_identifier = var.env == "prod" ? "${local.name}-final-snapshot" : null

  tags = {
    Name = "${local.name}-db"
    Env  = var.env
  }
}
