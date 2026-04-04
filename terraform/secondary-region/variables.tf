variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "dr-demo"
}

variable "primary_region" {
  description = "Primary AWS region (same for DR demo)"
  type        = string
  default     = "us-east-1"
}

variable "existing_vpc_name" {
  description = "Name of the existing VPC to use (same as primary)"
  type        = string
  default     = "eks-vpc"
}

variable "dr_availability_zones" {
  description = "Availability zones for DR (different from primary)"
  type        = list(string)
  default     = ["us-east-1b", "us-east-1c"]  # Different AZs for DR simulation
}

variable "secondary_backup_bucket_name" {
  description = "Name of the secondary backup bucket (from primary region)"
  type        = string
  default     = ""
}

variable "secondary_app_endpoint" {
  description = "Secondary application endpoint"
  type        = string
  default     = "dr-app-lb.us-east-1.elb.amazonaws.com"
}

variable "secondary_api_endpoint" {
  description = "Secondary API endpoint"
  type        = string
  default     = "dr-api-lb.us-east-1.elb.amazonaws.com"
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 90
}

variable "noncurrent_version_retention_days" {
  description = "Number of days to retain non-current versions"
  type        = number
  default     = 30
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dr"
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default = {
    Project     = "disaster-recovery-demo"
    Environment = "dr"
    ManagedBy   = "terraform"
  }
}
