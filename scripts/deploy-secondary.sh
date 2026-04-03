#!/bin/bash
set -e

echo "🚀 Deploying secondary region infrastructure and applications..."

# Get values from primary region
cd terraform/primary-region
PRIMARY_BUCKET=$(terraform output -raw primary_backup_bucket 2>/dev/null || echo "")
SECONDARY_BUCKET=$(terraform output -raw secondary_backup_bucket 2>/dev/null || echo "")
ROUTE53_ZONE=$(terraform output -raw route53_zone_id 2>/dev/null || echo "")
cd ../../

# Deploy Terraform for secondary region
echo "Deploying Terraform infrastructure for secondary region..."
cd terraform/secondary-region

# Set variables for secondary region
export TF_VAR_secondary_backup_bucket_name="$SECONDARY_BUCKET"
export TF_VAR_route53_zone_id="$ROUTE53_ZONE"

# Initialize and apply Terraform
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

cd ../../

# Configure kubectl for secondary EKS cluster
echo "Configuring kubectl for secondary cluster..."
aws eks update-kubeconfig --region ${TF_VAR_secondary_region:-us-west-2} --name ${TF_VAR_existing_eks_cluster_name:-dr-cluster} --alias secondary-cluster

# Verify cluster access
kubectl cluster-info --context=secondary-cluster > logs/secondary-cluster-info.log

# Deploy Kubernetes applications
echo "Deploying Kubernetes applications to secondary cluster..."
kubectl apply -f kubernetes/secondary/ --context=secondary-cluster

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/sample-app --context=secondary-cluster

# Get load balancer endpoint
echo "Getting load balancer endpoint..."
kubectl get services --context=secondary-cluster > logs/secondary-services.log

echo "✅ Secondary region deployment complete"
