resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids
}

# Frontend target group (default / route)
resource "aws_lb_target_group" "frontend" {
  name     = "${var.project_name}-tg-frontend"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path                = "/health"
    port                = "80"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Backend target group for API
resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-tg-backend"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path                = "/api.php"
    port                = "80"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  dynamic "default_action" {
    for_each = var.enable_https ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
  dynamic "default_action" {
    for_each = var.enable_https ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.frontend.arn
    }
  }
}

# Path-based rule to route /api/* to backend
resource "aws_lb_listener_rule" "api" {
  listener_arn = var.enable_https ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# Optional: ACM certificate (DNS validation) and HTTPS listener
resource "aws_acm_certificate" "cert" {
  count                     = var.enable_https && var.domain_name != "" ? 1 : 0
  domain_name               = var.domain_name
  validation_method         = "DNS"
  lifecycle { create_before_destroy = true }
  subject_alternative_names = var.include_www ? ["${var.www_subdomain}.${var.domain_name}"] : []
}

resource "aws_route53_zone" "this" {
  count = var.enable_https && var.domain_name != "" && var.create_hosted_zone && var.hosted_zone_id == "" ? 1 : 0
  name  = var.domain_name
}

data "aws_route53_zone" "existing" {
  count = var.enable_https && var.domain_name != "" && !var.create_hosted_zone && var.hosted_zone_id != "" ? 1 : 0
  zone_id = var.hosted_zone_id
}

locals {
  zone_id = var.enable_https && var.domain_name != "" ? (
    var.create_hosted_zone && var.hosted_zone_id == "" ? aws_route53_zone.this[0].zone_id : var.hosted_zone_id
  ) : null
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_https && var.domain_name != "" ? {
    for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}
  zone_id = local.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  count                   = var.enable_https && var.domain_name != "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for r in values(aws_route53_record.cert_validation) : r.fqdn]
}

resource "aws_lb_listener" "https" {
  count             = var.enable_https && var.domain_name != "" ? 1 : 0
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert[0].certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Alias record to ALB
resource "aws_route53_record" "alias" {
  count   = var.enable_https && var.domain_name != "" ? 1 : 0
  name    = var.domain_name
  type    = "A"
  zone_id = local.zone_id
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "alias_www" {
  count   = var.enable_https && var.domain_name != "" && var.include_www ? 1 : 0
  name    = "${var.www_subdomain}.${var.domain_name}"
  type    = "A"
  zone_id = local.zone_id
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

output "alb_dns" { value = aws_lb.alb.dns_name }
output "frontend_tg_arn" { value = aws_lb_target_group.frontend.arn }
output "backend_tg_arn" { value = aws_lb_target_group.backend.arn }
output "https_listener_arn" { value = try(aws_lb_listener.https[0].arn, null) }
output "domain_fqdn" { value = var.enable_https && var.domain_name != "" ? var.domain_name : null }
output "hosted_zone_id" { value = try(aws_route53_zone.this[0].zone_id, null) }
output "name_servers" { value = try(aws_route53_zone.this[0].name_servers, []) }
