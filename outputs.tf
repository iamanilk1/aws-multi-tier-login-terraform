output "alb_dns" { value = module.alb.alb_dns }
output "rds_endpoint" { value = module.rds.db_endpoint }
output "frontend_asg" { value = module.frontend.asg_name }
output "backend_asg" { value = module.backend.backend_asg_name }
output "hosted_zone_id" { value = try(module.alb.hosted_zone_id, null) }
output "name_servers" { value = try(module.alb.name_servers, []) }
