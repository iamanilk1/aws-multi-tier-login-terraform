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
  db_endpoint = module.rds.db_endpoint
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
}

// Root outputs are declared in outputs.tf; keep outputs centralized there.
