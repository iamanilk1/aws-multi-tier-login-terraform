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
    path                = "/"
    port                = "80"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200,404"
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
    matcher             = "200,404"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Path-based rule to route /api/* to backend
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
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

# Path-based rule to route /app/api/* to backend  
resource "aws_lb_listener_rule" "app_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 8
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
  condition {
    path_pattern {
      values = ["/app/api/*"]
    }
  }
}

output "alb_dns" { value = aws_lb.alb.dns_name }
output "frontend_tg_arn" { value = aws_lb_target_group.frontend.arn }
output "backend_tg_arn" { value = aws_lb_target_group.backend.arn }
