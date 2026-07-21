# ---------------------------------------------------------------
# VPC - public subnets host the ALB and the Fargate tasks (which get
# public IPs and reach ECR/Secrets Manager/CloudWatch Logs/SES over the
# public internet path), private subnets are RDS-only and have no route
# to the internet at all. No NAT Gateway - same cost-conscious call as
# terraform/eks-demo/network.tf, and stronger here: RDS never needs
# outbound access, so the private subnets aren't just NAT-less, they're
# genuinely isolated.
# ---------------------------------------------------------------

locals {
  az_count = 2
  vpc_cidr = "10.44.0.0/16"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "site-django"
    Project = "site-django"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "site-django"
  }
}

resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "site-django-public-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(local.vpc_cidr, 8, count.index + local.az_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "site-django-private-${count.index}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "site-django-public"
  }
}

resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private subnets intentionally get no route table association beyond the
# VPC's implicit local route - no internet route, no NAT, by design.

# ---------------------------------------------------------------
# Security groups
# ---------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "site-django-alb"
  description = "Internet-facing ALB for the Django site"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "site-django-alb"
  }
}

resource "aws_security_group_rule" "alb_ingress_https" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_ingress_http" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_egress" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "ecs" {
  name        = "site-django-ecs"
  description = "Fargate tasks running the Django app"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "site-django-ecs"
  }
}

resource "aws_security_group_rule" "ecs_ingress_from_alb" {
  security_group_id        = aws_security_group.ecs.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 8000
  to_port                  = 8000
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "ecs_egress" {
  security_group_id = aws_security_group.ecs.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "rds" {
  name        = "site-django-rds"
  description = "Postgres, reachable only from the ECS task security group"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "site-django-rds"
  }
}

resource "aws_security_group_rule" "rds_ingress_from_ecs" {
  security_group_id        = aws_security_group.rds.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  source_security_group_id = aws_security_group.ecs.id
}
