// Root for scenario2: simple-login infra
module "network" {
  source = "./modules/network"
  project_name = var.project_name
  vpc_cidr = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  azs = var.azs
}

module "security" {
  source = "./modules/security"
  project_name = var.project_name
  vpc_id = module.network.vpc_id
}

module "iam" {
  source = "./modules/iam"
  project_name = var.project_name
}

module "rds" {
  source = "./modules/rds"
  project_name = var.project_name
  vpc_id = module.network.vpc_id
  db_subnet_ids = module.network.private_subnet_ids
  security_group_ids = [module.security.db_sg_id]
  db_instance_class = var.db_instance_class
  db_engine_version = var.db_engine_version
  db_name = var.db_name
  multi_az = var.db_multi_az
  allocated_storage = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
}

module "alb" {
  source = "./modules/alb"
  project_name = var.project_name
  vpc_id = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  alb_sg_id = module.security.alb_sg_id
  enable_https = var.enable_https
  domain_name = var.domain_name
  create_hosted_zone = var.create_hosted_zone
  hosted_zone_id = var.hosted_zone_id
  include_www = var.include_www
  www_subdomain = var.www_subdomain
}

module "ecr" {
  source = "./modules/ecr"
  project_name = var.project_name
}

module "cicd" {
  source       = "./modules/cicd"
  project_name = var.project_name
  region       = var.region
  github_connection_name = var.github_connection_name
  github_repo_full_name  = var.github_repo_full_name
  github_branch          = var.github_branch
  ecr_repo_url = module.ecr.repo_url
  image_tag    = var.container_image_tag
}

module "frontend" {
  source = "./modules/frontend"
  project_name = var.project_name
  vpc_id = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
  alb_target_group_arn = module.alb.frontend_tg_arn
  instance_type = var.instance_type_frontend
  key_name = var.key_name
  desired_count = var.desired_frontend
  min_size = var.min_size
  max_size = var.max_size
  app_sg_id = module.security.app_sg_id
  instance_profile_name = module.iam.instance_profile_name
  # Container config
  aws_region = var.region
  ecr_repo_uri = module.ecr.repo_url
  image_tag = "frontend-${var.container_image_tag}"
}

module "backend" {
  source = "./modules/backend"
  project_name = var.project_name
  vpc_id = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
  instance_type = var.instance_type_backend
  key_name = var.key_name
  desired_count = var.desired_backend
  min_size = var.min_size
  max_size = var.max_size
  app_sg_id = module.security.app_sg_id
  db_endpoint = module.rds.db_endpoint
  db_password = module.rds.secret_password
  alb_target_group_arn = module.alb.backend_tg_arn
  db_name = var.db_name
  instance_profile_name = module.iam.instance_profile_name
  # Container config
  aws_region = var.region
  ecr_repo_uri = module.ecr.repo_url
  image_tag = "backend-${var.container_image_tag}"
}

// Autoscaling policies for frontend
resource "aws_autoscaling_policy" "frontend_scale_out_step" {
  name                   = "${var.project_name}-frontend-scale-out-step"
  autoscaling_group_name = module.frontend.asg_name
  policy_type            = "StepScaling"
  adjustment_type        = "ExactCapacity"

  # With a single alarm at threshold 30, these bounds are differences over 30
  # 30-49 (diff 0-19) => capacity 2
  step_adjustment {
    metric_interval_lower_bound = 0
    metric_interval_upper_bound = 20
    scaling_adjustment          = 2
  }
  # 50-99 (diff 20-69) => capacity 3
  step_adjustment {
    metric_interval_lower_bound = 20
    metric_interval_upper_bound = 70
    scaling_adjustment          = 3
  }
  # 100+ (diff >=70) => capacity 4 (max)
  step_adjustment {
    metric_interval_lower_bound = 70
    scaling_adjustment          = 4
  }
}

resource "aws_cloudwatch_metric_alarm" "frontend_req_gt_30" {
  alarm_name          = "${var.project_name}-frontend-requests-gt-30"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 30
  alarm_description   = "Frontend requests >= 30 in 1 minute"
  dimensions = {
    TargetGroup  = module.alb.frontend_tg_arn_suffix
    LoadBalancer = module.alb.alb_arn_suffix
  }
  alarm_actions = [aws_autoscaling_policy.frontend_scale_out_step.arn]
}

resource "aws_autoscaling_policy" "frontend_scale_in_exact_1" {
  name                   = "${var.project_name}-frontend-scale-in-1"
  autoscaling_group_name = module.frontend.asg_name
  policy_type            = "StepScaling"
  adjustment_type        = "ExactCapacity"
  step_adjustment {
    # For a LessThanThreshold alarm, use an upper bound of 0 to cover all
    # values below the threshold; avoids a positive upper bound requirement.
    metric_interval_upper_bound = 0
    scaling_adjustment          = 1
  }
}

resource "aws_cloudwatch_metric_alarm" "frontend_req_lt_10" {
  alarm_name          = "${var.project_name}-frontend-requests-lt-10"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Frontend requests < 10 for 2 minutes"
  dimensions = {
    TargetGroup  = module.alb.frontend_tg_arn_suffix
    LoadBalancer = module.alb.alb_arn_suffix
  }
  alarm_actions = [aws_autoscaling_policy.frontend_scale_in_exact_1.arn]
}

// Autoscaling policies for backend
resource "aws_autoscaling_policy" "backend_scale_out_step" {
  name                   = "${var.project_name}-backend-scale-out-step"
  autoscaling_group_name = module.backend.backend_asg_name
  policy_type            = "StepScaling"
  adjustment_type        = "ExactCapacity"

  # With a single alarm at threshold 30, these bounds are differences over 30
  # 30-49 (diff 0-19) => capacity 2
  step_adjustment {
    metric_interval_lower_bound = 0
    metric_interval_upper_bound = 20
    scaling_adjustment          = 2
  }
  # 50-99 (diff 20-69) => capacity 3
  step_adjustment {
    metric_interval_lower_bound = 20
    metric_interval_upper_bound = 70
    scaling_adjustment          = 3
  }
  # 100+ (diff >=70) => capacity 4 (max)
  step_adjustment {
    metric_interval_lower_bound = 70
    scaling_adjustment          = 4
  }
}

resource "aws_cloudwatch_metric_alarm" "backend_req_gt_30" {
  alarm_name          = "${var.project_name}-backend-requests-gt-30"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 30
  alarm_description   = "Backend requests >= 30 in 1 minute"
  dimensions = {
    TargetGroup  = module.alb.backend_tg_arn_suffix
    LoadBalancer = module.alb.alb_arn_suffix
  }
  alarm_actions = [aws_autoscaling_policy.backend_scale_out_step.arn]
}

resource "aws_autoscaling_policy" "backend_scale_in_exact_1" {
  name                   = "${var.project_name}-backend-scale-in-1"
  autoscaling_group_name = module.backend.backend_asg_name
  policy_type            = "StepScaling"
  adjustment_type        = "ExactCapacity"
  step_adjustment {
    # For a LessThanThreshold alarm, use an upper bound of 0 to cover all
    # values below the threshold; avoids a positive upper bound requirement.
    metric_interval_upper_bound = 0
    scaling_adjustment          = 1
  }
}

resource "aws_cloudwatch_metric_alarm" "backend_req_lt_10" {
  alarm_name          = "${var.project_name}-backend-requests-lt-10"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Backend requests < 10 for 2 minutes"
  dimensions = {
    TargetGroup  = module.alb.backend_tg_arn_suffix
    LoadBalancer = module.alb.alb_arn_suffix
  }
  alarm_actions = [aws_autoscaling_policy.backend_scale_in_exact_1.arn]
}

// Root outputs are declared in outputs.tf; keep outputs centralized there.
