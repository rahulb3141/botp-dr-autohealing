terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.39.0"
    }
  }
}

provider "aws" {
  region = var.secondary_region
}

# Data sources for existing resources
data "aws_caller_identity" "current" {}

# Existing VPC in secondary region
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = [var.existing_vpc_name]
  }
}

# S3 Bucket Lifecycle Policy for DR backups (using existing bucket)
data "aws_s3_bucket" "secondary_backups" {
  bucket = var.secondary_backup_bucket_name
}

resource "aws_s3_bucket_lifecycle_configuration" "secondary_backups" {
  bucket = data.aws_s3_bucket.secondary_backups.id

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

# Route 53 Record for DR region direct access
data "aws_route53_zone" "existing" {
  zone_id = var.route53_zone_id
}

resource "aws_route53_record" "dr_direct" {
  zone_id = data.aws_route53_zone.existing.zone_id
  name    = "dr.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.secondary_app_endpoint]
}

# Route 53 Record for API endpoint in DR
resource "aws_route53_record" "api_dr" {
  zone_id = data.aws_route53_zone.existing.zone_id
  name    = "api-dr.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.secondary_api_endpoint]
}

# Route 53 Record for admin access in DR
resource "aws_route53_record" "admin_dr" {
  zone_id = data.aws_route53_zone.existing.zone_id
  name    = "admin-dr.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.secondary_admin_endpoint]
}
