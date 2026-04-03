terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.39.0"
    }
  }
}

provider "aws" {
  region = var.primary_region
}

# Secondary region provider for S3 replication
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

# Data sources for existing resources
data "aws_caller_identity" "current" {}

# Existing VPC
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = [var.existing_vpc_name]
  }
}

# Existing IAM role for S3 replication
data "aws_iam_role" "existing_replication_role" {
  name = var.existing_replication_role_name
}

# S3 Bucket for Primary Backups
resource "aws_s3_bucket" "primary_backups" {
  bucket = "${var.project_name}-backups-primary-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-primary-backups"
    Environment = "production"
    Project     = var.project_name
    VPC         = data.aws_vpc.existing.id
  }
}

resource "aws_s3_bucket_versioning" "primary_backups" {
  bucket = aws_s3_bucket.primary_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary_backups" {
  bucket = aws_s3_bucket.primary_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "primary_backups" {
  bucket = aws_s3_bucket.primary_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket for Secondary Region Backups
resource "aws_s3_bucket" "secondary_backups" {
  provider = aws.secondary
  bucket   = "${var.project_name}-backups-secondary-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-secondary-backups"
    Environment = "production"
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_versioning" "secondary_backups" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secondary_backups" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "secondary_backups" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Cross-Region Replication (using existing IAM role)
resource "aws_s3_bucket_replication_configuration" "replication" {
  role   = data.aws_iam_role.existing_replication_role.arn
  bucket = aws_s3_bucket.primary_backups.id

  rule {
    id     = "backup_replication"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.secondary_backups.arn
      storage_class = "STANDARD_IA"
    }
  }

  depends_on = [aws_s3_bucket_versioning.primary_backups]
}

# Route 53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name

  # Associate with existing VPC if specified
  dynamic "vpc" {
    for_each = var.associate_with_vpc ? [1] : []
    content {
      vpc_id = data.aws_vpc.existing.id
    }
  }

  tags = {
    Name    = "${var.project_name}-hosted-zone"
    Project = var.project_name
    VPC     = data.aws_vpc.existing.id
  }
}

# Route 53 Health Check for Primary Region
resource "aws_route53_health_check" "primary" {
  fqdn                            = var.primary_app_endpoint
  port                            = var.health_check_port
  type                            = var.health_check_protocol
  resource_path                   = var.health_check_path
  failure_threshold               = 3
  request_interval                = 30

  tags = {
    Name    = "${var.project_name}-primary-health-check"
    Project = var.project_name
  }
}

# Route 53 Health Check for Secondary Region
resource "aws_route53_health_check" "secondary" {
  fqdn                            = var.secondary_app_endpoint
  port                            = var.health_check_port
  type                            = var.health_check_protocol
  resource_path                   = var.health_check_path
  failure_threshold               = 3
  request_interval                = 30

  tags = {
    Name    = "${var.project_name}-secondary-health-check"
    Project = var.project_name
  }
}

# Route 53 DNS Records for Failover - Primary
resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "app.${var.domain_name}"
  type    = "CNAME"
  ttl     = 60

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary.id
  set_identifier  = "primary"
  records         = [var.primary_app_endpoint]
}

# Route 53 DNS Records for Failover - Secondary
resource "aws_route53_record" "secondary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "app.${var.domain_name}"
  type    = "CNAME"
  ttl     = 60

  failover_routing_policy {
    type = "SECONDARY"
  }

  health_check_id = aws_route53_health_check.secondary.id
  set_identifier  = "secondary"
  records         = [var.secondary_app_endpoint]
}

# Random string for unique bucket names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}
