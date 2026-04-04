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
    values = [var.dr_availability_zones]
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
    values = [var.dr_availability_zones]
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

# Route 53 Records for DR (different subdomain)
data "aws_route53_zone" "existing" {
  count   = var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
}

resource "aws_route53_record" "dr_direct" {
  count   = var.route53_zone_id != "" ? 1 : 0
  zone_id = data.aws_route53_zone.existing[0].zone_id
  name    = "dr.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.secondary_app_endpoint]
}

resource "aws_route53_record" "api_dr" {
  count   = var.route53_zone_id != "" ? 1 : 0
  zone_id = data.aws_route53_zone.existing[0].zone_id
  name    = "api-dr.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.secondary_api_endpoint]
}

# CloudWatch Dashboard for DR monitoring
resource "aws_cloudwatch_dashboard" "dr_dashboard" {
  dashboard_name = "${var.project_name}-dr-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", var.secondary_backup_bucket_name, "StorageType", "StandardStorage"],
            ["AWS/S3", "NumberOfObjects", "BucketName", var.secondary_backup_bucket_name, "StorageType", "AllStorageTypes"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.primary_region
          title   = "DR S3 Backup Metrics"
          period  = 300
        }
      }
    ]
  })
}
