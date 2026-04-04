terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.39.0"
    }
  }
}

provider "aws" {
  region = var.primary_region  # Same region as primary
}

# Data sources for existing resources
data "aws_caller_identity" "current" {}

# Use the SAME existing VPC as primary
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = [var.existing_vpc_name]
  }
}

# Get different subnets for DR simulation
data "aws_subnets" "existing_private_dr" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
  
  # Get different AZs for DR
  filter {
    name   = "availability-zone"
    values = var.dr_availability_zones
  }
}

data "aws_subnets" "existing_public_dr" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["public"]
  }
  
  filter {
    name   = "availability-zone"
    values = var.dr_availability_zones
  }
}

# S3 Bucket Lifecycle Policy for DR backups
data "aws_s3_bucket" "secondary_backups" {
  count  = var.secondary_backup_bucket_name != "" ? 1 : 0
  bucket = var.secondary_backup_bucket_name
}

resource "aws_s3_bucket_lifecycle_configuration" "secondary_backups" {
  count  = var.secondary_backup_bucket_name != "" ? 1 : 0
  bucket = data.aws_s3_bucket.secondary_backups[0].id

  rule {
    id     = "dr_backup_lifecycle"
    status = "Enabled"

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }
  }
}
