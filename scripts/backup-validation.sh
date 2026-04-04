#!/bin/bash
set -e

echo "í´ Validating S3 buckets..."

PRIMARY_BUCKET="dr-demo-backups-primary-v9ap3fcu"
SECONDARY_BUCKET="dr-demo-backups-secondary-v9ap3fcu"

echo "Testing bucket access..."

# Test primary bucket (check exit code, not output)
if aws s3 ls s3://$PRIMARY_BUCKET >/dev/null 2>&1; then
    echo "âœ… Primary bucket accessible: $PRIMARY_BUCKET"
else
    echo "âŒ Primary bucket not accessible: $PRIMARY_BUCKET"
    aws s3 ls s3://$PRIMARY_BUCKET 2>&1 || true
    exit 1
fi

# Test secondary bucket (check exit code, not output)
if aws s3 ls s3://$SECONDARY_BUCKET >/dev/null 2>&1; then
    echo "âœ… Secondary bucket accessible: $SECONDARY_BUCKET"
else
    echo "âŒ Secondary bucket not accessible: $SECONDARY_BUCKET"
    aws s3 ls s3://$SECONDARY_BUCKET 2>&1 || true
    exit 1
fi

echo "âœ… S3 validation complete"
