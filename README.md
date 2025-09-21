Project: Simple Login (Senior) - Terraform infrastructure

This folder contains Terraform code that provisions a multi-tier architecture for a simple login application on AWS:
- VPC with public and private subnets across 2 AZs
- Security groups for ALB, application instances, and RDS
- ALB (public) with path-based routing and two Target Groups (frontend, backend)
- Frontend AutoScaling Group (behind ALB)
- Backend AutoScaling Group (behind ALB on /api/*)
- RDS MySQL instance in private subnets

Quick start
1. cd scenario2
2. Create a `terraform.tfvars` file with required values (see `variables.tf`) or pass via CLI
3. terraform init
4. terraform plan
5. terraform apply

Notes
Variables to consider (sample tfvars)
project_name = "simple-login"
region       = "ap-south-1"
azs          = ["ap-south-1a", "ap-south-1b"]
vpc_cidr     = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]
instance_type_frontend = "t3.micro"
instance_type_backend  = "t3.micro"
desired_frontend = 2
desired_backend  = 2
min_size = 1
max_size = 3
key_name = "your-ec2-keypair"
db_instance_class = "db.t3.micro"
db_engine_version = "8.0.32"
db_name = "appdb"
db_multi_az = false
db_allocated_storage = 20
db_max_allocated_storage = 100

How to test
- After apply, note the output `alb_dns`.
- If using HTTPS + custom domain, you won’t use ALB DNS; see below. Otherwise, open http://ALB_DNS/ for frontend and http://ALB_DNS/api/ (or /api/api.php) for backend.

Notes
- NAT Gateways are created per AZ to allow private instances to reach the Internet for updates, improving availability.
- This is an opinionated, minimal example to bootstrap the infrastructure. It uses Launch Templates + ASG for compute.
- Provide an SSH key in `key_name` for debugging access if needed.
- Review security groups before applying to ensure they meet your security posture.

Using your domain with HTTPS (Route 53 + ACM)
1) In terraform.tfvars, set:
	enable_https       = true
	domain_name        = "iamanilk.space"
	create_hosted_zone = true
	hosted_zone_id     = ""
2) terraform apply
3) After apply, copy the `name_servers` output. Go to your domain registrar for iamanilk.space and update the domain’s nameservers to those four Route 53 NS values.
4) Wait for DNS propagation (can take up to 30–60 minutes). The ACM DNS validation record is created automatically; once propagated, the certificate becomes “Issued”.
5) Browse to https://iamanilk.space — HTTP will redirect to HTTPS automatically.

If you already have a Zone in Route 53
Set:
	enable_https       = true
	domain_name        = "iamanilk.space"
	create_hosted_zone = false
	hosted_zone_id     = "ZXXXXXXXXXXXXX"  # your existing zone id
