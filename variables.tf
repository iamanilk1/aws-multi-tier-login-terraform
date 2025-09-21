variable "project_name" {
  type    = string
  default = "simple-login"
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "azs" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "instance_type_frontend" {
  type    = string
  default = "t3.micro"
}

variable "instance_type_backend" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type = string
  default = ""
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_engine_version" {
  type        = string
  description = "Optional MySQL engine version (e.g., 8.0.36). Leave empty to use the latest supported in the region."
  default     = ""
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_max_allocated_storage" {
  type    = number
  default = 100
}

variable "desired_frontend" {
  type    = number
  default = 1
}

variable "desired_backend" {
  type    = number
  default = 1
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}

# HTTPS and DNS
variable "enable_https" {
  type    = bool
  default = false
}
variable "domain_name" {
  type    = string
  default = ""
}
variable "create_hosted_zone" {
  type    = bool
  default = true
}
variable "hosted_zone_id" {
  type    = string
  default = ""
}
variable "include_www" {
  type    = bool
  default = false
}
variable "www_subdomain" {
  type    = string
  default = "www"
}

# Containerization
variable "container_image_tag" {
  type        = string
  description = "Tag to deploy for frontend/backend containers in ECR"
  default     = "latest"
}

# CICD (GitHub via CodeStar Connections)
variable "github_connection_name" {
  type        = string
  description = "Name for the CodeStar Connections connection to GitHub"
  default     = "github-connection"
}

variable "github_repo_full_name" {
  type        = string
  description = "GitHub repository full name (owner/repo)"
}

variable "github_branch" {
  type        = string
  description = "Git branch to build from"
  default     = "main"
}
