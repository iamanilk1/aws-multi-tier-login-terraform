resource "random_password" "db" {
  length = 16
  override_special = "@#$%&*"
}

resource "aws_db_subnet_group" "this" {
  name = "${var.project_name}-db-subnet-group"
  subnet_ids = var.db_subnet_ids
}

resource "aws_db_instance" "this" {
  allocated_storage    = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  engine = "mysql"
  engine_version = var.db_engine_version == "" ? null : var.db_engine_version
  instance_class = var.db_instance_class
  username = "appuser"
  password = random_password.db.result
  db_name = var.db_name
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  skip_final_snapshot = true
  multi_az = var.multi_az
}

output "db_endpoint" { value = aws_db_instance.this.address }
output "db_port" { value = aws_db_instance.this.port }
output "secret_password" { value = random_password.db.result }
