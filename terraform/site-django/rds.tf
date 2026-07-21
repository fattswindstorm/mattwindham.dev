resource "aws_db_subnet_group" "this" {
  name       = "site-django"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "site-django"
  }
}

resource "aws_db_instance" "this" {
  identifier     = "site-django"
  engine         = "postgres"
  engine_version = "16"

  # db.t4g.micro Single-AZ PostgreSQL on-demand: $0.016/hr (~$11.68/mo) as
  # of this pricing check, plus 20GB gp3 storage (~$0.115/GB-mo, ~$2.30/mo).
  instance_class    = "db.t4g.micro"
  allocated_storage = 20
  storage_type      = "gp3"
  multi_az          = false

  db_name  = var.db_name
  username = var.db_username

  # Master credential lives in an AWS-managed Secrets Manager secret rather
  # than Terraform state/variables - the ECS task definition reads it
  # directly via a secrets ARN reference (see ecs.tf).
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "site-django-final"

  tags = {
    Name    = "site-django"
    Project = "site-django"
  }
}
