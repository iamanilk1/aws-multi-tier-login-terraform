resource "aws_launch_template" "front" {
  name_prefix = "${var.project_name}-front-"
  image_id = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name = var.key_name
  vpc_security_group_ids = [var.app_sg_id]
  iam_instance_profile { name = var.instance_profile_name }
  update_default_version = true
  user_data = base64encode(templatefile("${path.module}/user_data.tpl", {
    aws_region = var.aws_region,
    ecr_repo_uri = var.ecr_repo_uri,
    image_tag = var.image_tag
  }))
}

resource "aws_autoscaling_group" "front_asg" {
  name               = "${var.project_name}-frontend-asg"
  desired_capacity = var.desired_count
  min_size = var.min_size
  max_size = var.max_size
  vpc_zone_identifier = var.subnet_ids
  force_delete        = true
  launch_template {
    id = aws_launch_template.front.id
    version = "$Latest"
  }
  target_group_arns = [var.alb_target_group_arn]
  default_cooldown = 120
  health_check_grace_period = 180
  tag {
    key = "Name"
    value = "${var.project_name}-front"
    propagate_at_launch = true
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

