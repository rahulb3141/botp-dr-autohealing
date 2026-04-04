#!/bin/bash
set -e

echo "✅ Validating backup and DR infrastructure..."

# Validate Terraform configurations
echo "Validating Terraform deployments..."

# Check primary region Terraform
if [ -d "terraform/primary-region" ]; then
    echo "Validating primary region Terraform..."
    cd terraform/primary-region
    terraform validate
    cd ../..
fi

# Check secondary region Terraform  
if [ -d "terraform/secondary-region" ]; then
    echo "Validating secondary region Terraform..."
    cd terraform/secondary-region
    terraform validate
    cd ../..
fi

# Validate S3 buckets
echo "Validating S3 buckets..."

PRIMARY_BUCKET="dr-demo-backups-primary-v9ap3fcu"
SECONDARY_BUCKET="dr-demo-backups-secondary-v9ap3fcu"

echo "Testing bucket access..."

# Test primary bucket
if aws s3 ls s3://$PRIMARY_BUCKET >/dev/null 2>&1; then
    echo "✅ Primary bucket accessible: $PRIMARY_BUCKET"
else
    echo "❌ Primary bucket not accessible: $PRIMARY_BUCKET"
    exit 1
fi

# Test secondary bucket
if aws s3 ls s3://$SECONDARY_BUCKET >/dev/null 2>&1; then
    echo "✅ Secondary bucket accessible: $SECONDARY_BUCKET"
else
    echo "❌ Secondary bucket not accessible: $SECONDARY_BUCKET"
    exit 1
fi

echo "✅ S3 validation complete"
echo "✅ Backup and DR infrastructure validation successful"
