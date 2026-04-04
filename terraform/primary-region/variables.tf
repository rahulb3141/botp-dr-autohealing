variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "dr-demo"
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for DR"
  type        = string
  default     = "us-west-2"
}

variable "existing_vpc_name" {
  description = "Name of the existing VPC to use"
  type        = string
  default     = "eks-vpc"
}

variable "existing_replication_role_name" {
  description = "Name of the existing IAM role for S3 replication"
  type        = string
  default     = "s3-replication-role"
}


variable "associate_with_vpc" {
  description = "Whether to associate Route53 zone with VPC (private hosted zone)"
  type        = bool
  default     = false
}

variable "primary_app_endpoint" {
  description = "Primary application endpoint for Route53 failover"
  type        = string
  default     = "primary-app-lb.us-east-1.elb.amazonaws.com"
}

variable "secondary_app_endpoint" {
  description = "Secondary application endpoint for Route53 failover"
  type        = string
  default     = "secondary-app-lb.us-west-2.elb.amazonaws.com"
}

variable "health_check_protocol" {
  description = "Protocol for Route53 health checks"
  type        = string
  default     = "HTTP"
  validation {
    condition     = contains(["HTTP", "HTTPS", "TCP"], var.health_check_protocol)
    error_message = "Health check protocol must be HTTP, HTTPS, or TCP."
  }
}

variable "health_check_port" {
  description = "Port for Route53 health checks"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Path for Route53 health checks"
  type        = string
  default     = "/health"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

