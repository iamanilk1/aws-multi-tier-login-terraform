output "alb_dns" { value = module.alb.alb_dns }
output "rds_endpoint" { value = module.rds.db_endpoint }
output "frontend_asg" { value = module.frontend.asg_name }
output "backend_asg" { value = module.backend.backend_asg_name }
output "hosted_zone_id" { value = try(module.alb.hosted_zone_id, null) }
output "name_servers" { value = try(module.alb.name_servers, []) }
output "ecr_repo" { value = module.ecr.repo_url }
output "cicd_artifact_bucket" { value = module.cicd.artifact_bucket }
output "pipeline_frontend_name" { value = module.cicd.pipeline_frontend_name }
output "pipeline_backend_name" { value = module.cicd.pipeline_backend_name }
output "github_connection_arn" { value = module.cicd.github_connection_arn }

# Network SSM VPC interface endpoint IDs (map service -> id)
output "ssm_vpc_endpoint_ids" { value = try(module.network.ssm_vpc_endpoint_ids, {}) }
