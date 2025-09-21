resource "random_password" "db" {
  length           = 16
  override_special = "@#$%&*"
}

# Creation-time timestamp to build a stable final snapshot name
resource "time_static" "rds_final" {}

# Stable, sanitized DB instance identifier and final snapshot id
locals {
  # Lowercase and replace common disallowed chars with hyphen; then trim trailing dash
  # Note: We avoid regexreplace for broad compatibility
  db_identifier = trimsuffix(
    "${lower(
      replace(
        replace(
          replace(
            replace(var.project_name, " ", "-"),
          "_", "-"),
        ".", "-"),
      "/", "-")
    )}-rds",
    "-"
  )
  final_snapshot_id  = "${local.db_identifier}-final-${formatdate("YYYYMMDDhhmmss", time_static.rds_final.rfc3339)}"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.db_subnet_ids
}

resource "aws_db_instance" "this" {
  identifier             = local.db_identifier
  allocated_storage      = var.allocated_storage
  max_allocated_storage  = var.max_allocated_storage
  engine                 = "mysql"
  engine_version         = var.db_engine_version == "" ? null : var.db_engine_version
  instance_class         = var.db_instance_class
  username               = "appuser"
  password               = random_password.db.result
  db_name                = var.db_name
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  multi_az               = var.multi_az
  apply_immediately      = true

  # Ensure a final snapshot is taken on replacement/deletion
  skip_final_snapshot       = false
  final_snapshot_identifier = local.final_snapshot_id

  lifecycle {
    create_before_destroy = true
  }
}

output "db_endpoint" { value = aws_db_instance.this.address }
output "db_port" { value = aws_db_instance.this.port }
output "secret_password" { value = random_password.db.result }
output "db_identifier" { value = aws_db_instance.this.id }
