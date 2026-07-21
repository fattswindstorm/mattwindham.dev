resource "aws_ecs_cluster" "this" {
  name = "site-django"
}

resource "aws_cloudwatch_log_group" "django" {
  name              = "/ecs/site-django"
  retention_in_days = 30
}

# Initial container definition, bootstrapping the task definition family so
# the ECS service has something to reference on first apply. Once the CI
# pipeline (.github/workflows/build-django-image.yml) starts registering
# its own new revisions with real image tags, aws_ecs_service.django's
# `ignore_changes = [task_definition]` below stops Terraform from fighting
# those out-of-band updates on subsequent applies - the service keeps
# whatever revision CI last pointed it at.
resource "aws_ecs_task_definition" "django" {
  family                   = "site-django"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "django"
      image = "${aws_ecr_repository.django_site.repository_url}:bootstrap"
      portMappings = [
        { containerPort = 8000, protocol = "tcp" }
      ]
      environment = [
        { name = "DJANGO_DEBUG", value = "false" },
        { name = "DJANGO_ALLOWED_HOSTS", value = "${var.staging_subdomain}.${var.domain_name}" },
        { name = "DJANGO_CSRF_TRUSTED_ORIGINS", value = "https://${var.staging_subdomain}.${var.domain_name}" },
        { name = "PGHOST", value = aws_db_instance.this.address },
        { name = "PGPORT", value = tostring(aws_db_instance.this.port) },
        { name = "PGDATABASE", value = var.db_name },
        { name = "PGUSER", value = var.db_username },
        { name = "AWS_SES_REGION_NAME", value = var.aws_region },
        { name = "DEFAULT_FROM_EMAIL", value = "noreply@${var.domain_name}" },
        { name = "NOTIFY_EMAIL", value = var.notify_email },
      ]
      secrets = [
        { name = "DJANGO_SECRET_KEY", valueFrom = aws_secretsmanager_secret.django_secret_key.arn },
        { name = "PGPASSWORD", valueFrom = "${aws_db_instance.this.master_user_secret[0].secret_arn}:password::" },
        { name = "GOOGLE_CLIENT_ID", valueFrom = aws_secretsmanager_secret.google_client_id.arn },
        { name = "GOOGLE_CLIENT_SECRET", valueFrom = aws_secretsmanager_secret.google_client_secret.arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.django.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "django"
        }
      }
    }
  ])

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

resource "aws_ecs_service" "django" {
  name            = "site-django"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.django.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.django.arn
    container_name   = "django"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.https]

  lifecycle {
    ignore_changes = [task_definition]
  }
}
