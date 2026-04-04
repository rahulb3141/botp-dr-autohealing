#!/bin/bash
set -e

echo "🚀 Deploying primary region infrastructure and applications..."

## Deploy Terraform for primary region
echo "Deploying Terraform infrastructure..."
cd terraform/primary-region

# Initialize and apply Terraform
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

# Get outputs for Kubernetes deployment
S3_BUCKET=$(terraform output -raw primary_backup_bucket 2>/dev/null || echo "")
ROUTE53_ZONE=$(terraform output -raw route53_zone_id 2>/dev/null || echo "")

cd ../../

# Configure kubectl for primary EKS cluster
echo "Configuring kubectl for primary cluster..."
aws eks update-kubeconfig --region ${TF_VAR_primary_region:-us-east-1} --name ${TF_VAR_existing_eks_cluster_name:-eks-cluster} --alias primary-cluster

# Verify cluster access
kubectl cluster-info --context=primary-cluster > logs/primary-cluster-info.log

# Deploy Kubernetes applications
echo "Deploying Kubernetes applications to primary cluster..."
kubectl apply -f kubernetes/primary/ --context=primary-cluster

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/sample-app --context=primary-cluster

# Get load balancer endpoint
echo "Getting load balancer endpoint..."
kubectl get services --context=primary-cluster > logs/primary-services.log

echo "✅ Primary region deployment complete"
