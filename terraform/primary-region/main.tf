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

# S3 Bucket for Primary Backups
resource "aws_s3_bucket" "primary_backups" {
  bucket = "${var.project_name}-backups-primary-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-primary-backups"
    Environment = "production"
    Project     = var.project_name
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

# Cross-Region Replication IAM Role
resource "aws_iam_role" "replication" {
  name = "${var.project_name}-s3-replication-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = {
    Name    = "${var.project_name}-s3-replication-role"
    Project = var.project_name
  }
}

resource "aws_iam_policy" "replication" {
  name = "${var.project_name}-s3-replication-policy"

  policy = jsonencode({
    Statement = [
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = "${aws_s3_bucket.primary_backups.arn}/*"
      },
      {
        Action = [
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = aws_s3_bucket.primary_backups.arn
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = "${aws_s3_bucket.secondary_backups.arn}/*"
      }
    ]
    Version = "2012-10-17"
  })

  tags = {
    Name    = "${var.project_name}-s3-replication-policy"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

# S3 Cross-Region Replication
resource "aws_s3_bucket_replication_configuration" "replication" {
  role   = aws_iam_role.replication.arn
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

  tags = {
    Name    = "${var.project_name}-hosted-zone"
    Project = var.project_name
  }
}

# Route 53 Health Check for Primary Region
resource "aws_route53_health_check" "primary" {
  fqdn                            = var.primary_app_endpoint
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/health"
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
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/health"
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
