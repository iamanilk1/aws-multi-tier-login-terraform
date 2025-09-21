resource "aws_launch_template" "backend" {
  name_prefix = "${var.project_name}-back-"
  image_id = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name = var.key_name
  vpc_security_group_ids = [var.app_sg_id]
  iam_instance_profile { name = var.instance_profile_name }
  user_data = base64encode(templatefile("${path.module}/user_data.tpl", {
    db_endpoint = var.db_endpoint,
    db_password = var.db_password,
    db_name = var.db_name,
    aws_region = var.aws_region,
    ecr_repo_uri = var.ecr_repo_uri,
    image_tag = var.image_tag
  }))
}

resource "aws_autoscaling_group" "back_asg" {
  desired_capacity = var.desired_count
  min_size = var.min_size
  max_size = var.max_size
  vpc_zone_identifier = var.subnet_ids
  launch_template {
    id = aws_launch_template.backend.id
    version = "$Latest"
  }
  target_group_arns = [var.alb_target_group_arn]
  tag {
    key = "Name"
    value = "${var.project_name}-back"
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


