#!/bin/bash
set -e

echo "🚀 Deploying secondary region infrastructure..."

# Create logs directory
mkdir -p logs

# Deploy Terraform for secondary region
echo "📦 Deploying Terraform infrastructure for DR region..."
cd terraform/secondary-region
terraform init
terraform plan -out=tfplan
terraform apply tfplan
cd ../..

# Get EKS cluster credentials for secondary region
echo "🔑 Configuring kubectl for secondary cluster..."
aws eks update-kubeconfig --region us-west-2 --name secondary-cluster --alias secondary-cluster

# Deploy Kubernetes resources to secondary region
echo "☸️  Deploying Kubernetes resources to DR region..."
kubectl apply -f kubernetes/secondary/

echo "✅ Secondary region deployment completed successfully!"

