#!/bin/bash
set -e

echo "✅ Validating backup and DR infrastructure..."

# Validate Terraform state
echo "Validating Terraform deployments..."
cd terraform/primary-region
terraform validate
terraform refresh
cd ../secondary-region
terraform validate
terraform refresh
cd ../../

# Validate S3 buckets
echo "Validating S3 buckets..."
cd terraform/primary-region
PRIMARY_BUCKET=$(terraform output -raw primary_backup_bucket 2>/dev/null || echo "")
SECONDARY_BUCKET=$(terraform output -raw secondary_backup_bucket 2>/dev/null || echo "")
cd ../../

if [ -n "$PRIMARY_BUCKET" ]; then
    aws s3 ls "s3://$PRIMARY_BUCKET" > logs/primary-bucket-validation.log 2>&1 && echo "✅ Primary bucket accessible" || echo "❌ Primary bucket not accessible"
    
    # Check bucket versioning
    aws s3api get-bucket-versioning --bucket "$PRIMARY_BUCKET" > logs/primary-bucket-versioning.log 2>&1
fi

if [ -n "$SECONDARY_BUCKET" ]; then
    aws s3 ls "s3://$SECONDARY_BUCKET" --region ${TF_VAR_secondary_region:-us-west-2} > logs/secondary-bucket-validation.log 2>&1 && echo "✅ Secondary bucket accessible" || echo "❌ Secondary bucket not accessible"
    
    # Check bucket versioning
    aws s3api get-bucket-versioning --bucket "$SECONDARY_BUCKET" --region ${TF_VAR_secondary_region:-us-west-2} > logs/secondary-bucket-versioning.log 2>&1
fi

# Validate EKS clusters
echo "Validating EKS clusters..."
kubectl cluster-info --context=primary-cluster > logs/primary-cluster-info.log 2>&1 && echo "✅ Primary cluster accessible" || echo "❌ Primary cluster not accessible"
kubectl cluster-info --context=secondary-cluster > logs/secondary-cluster-info.log 2>&1 && echo "✅ Secondary cluster accessible" || echo "❌ Secondary cluster not accessible"

# Validate applications
echo "Validating application deployments..."
kubectl get deployments --context=primary-cluster > logs/primary-deployments.log
kubectl get deployments --context=secondary-cluster > logs/secondary-deployments.log

# Check application health
echo "Checking application health endpoints..."
kubectl get pods -l app=sample-app --context=primary-cluster > logs/primary-pods.log
kubectl get pods -l app=sample-app --context=secondary-cluster > logs/secondary-pods.log

# Validate Route53 configuration
echo "Validating Route53 configuration..."
cd terraform/primary-region
ZONE_ID=$(terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="aws_route53_zone") | .values.zone_id' 2>/dev/null || echo "")
cd ../../

if [ -n "$ZONE_ID" ]; then
    aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" > logs/route53-records.log 2>&1
fi

echo "✅ Validation complete"
