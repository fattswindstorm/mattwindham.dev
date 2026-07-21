resource "aws_lb" "this" {
  name               = "site-django"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "django" {
  name        = "site-django"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip"

  health_check {
    path                = "/healthz/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  # Reuses the wildcard cert from terraform/site (via remote state) rather
  # than provisioning a second one - see remote_state.tf.
  certificate_arn = data.terraform_remote_state.site.outputs.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.django.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Staging record pointing directly at the ALB, independent of the apex/www
# records CloudFront still owns until Phase 3's cutover - lets this stack
# be verified against a real domain/cert before touching production DNS.
resource "aws_route53_record" "staging" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${var.staging_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}
