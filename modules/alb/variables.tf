variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "alb_sg_id" { type = string }

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
