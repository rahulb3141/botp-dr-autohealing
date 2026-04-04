#!/bin/bash
set -e

echo "🚀 Deploying DR environment (same region, different AZs)..."

# Get values from primary region
cd terraform/primary-region
PRIMARY_BUCKET=$(terraform output -raw primary_backup_bucket 2>/dev/null || echo "")
SECONDARY_BUCKET=$(terraform output -raw secondary_backup_bucket 2>/dev/null || echo "")
ROUTE53_ZONE=$(terraform output -raw route53_zone_id 2>/dev/null || echo "")
cd ../../

# Deploy Terraform for DR (same region)
echo "Setting up DR configuration..."
cd terraform/secondary-region

# Set variables for DR
export TF_VAR_secondary_backup_bucket_name="$SECONDARY_BUCKET"
export TF_VAR_route53_zone_id="$ROUTE53_ZONE"

# Initialize and apply Terraform
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

cd ../../

# Use the same EKS cluster but deploy to different namespace/AZs
echo "Deploying DR applications to existing cluster..."
kubectl create namespace dr-demo --dry-run=client -o yaml | kubectl apply -f -

# Deploy Kubernetes applications with DR configuration
kubectl apply -f kubernetes/secondary/ -n dr-demo

# Wait for deployments to be ready
echo "Waiting for DR deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/sample-app-dr -n dr-demo

# Get service information
echo "Getting DR service information..."
kubectl get services -n dr-demo > logs/dr-services.log

echo "✅ DR environment deployment complete"
echo "DR Namespace: dr-demo"
echo "DR running in different AZs within same region"
