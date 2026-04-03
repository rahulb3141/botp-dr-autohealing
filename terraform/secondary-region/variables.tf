variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "dr-demo"
}

variable "secondary_region" {
  description = "Secondary AWS region for DR"
  type        = string
  default     = "us-west-2"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size_dr" {
  description = "Desired number of nodes in the DR EKS node group (pilot light)"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes in the EKS node group"
  type        = number
  default     = 6
}

variable "node_min_size_dr" {
  description = "Minimum number of nodes in the DR EKS node group"
  type        = number
  default     = 0
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dr"
}
