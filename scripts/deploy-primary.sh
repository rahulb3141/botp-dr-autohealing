#!/bin/bash
set -e

echo "🚀 Deploying primary region infrastructure..."

# Create logs directory
mkdir -p logs

# Deploy Terraform for primary region
echo "📦 Deploying Terraform infrastructure..."
cd terraform/primary-region
terraform init
terraform plan -out=tfplan
terraform apply tfplan
cd ../..

# Get EKS cluster credentials
echo "🔑 Configuring kubectl for primary cluster..."
aws eks update-kubeconfig --region us-east-1 --name primary-cluster --alias primary-cluster

# Deploy Kubernetes resources
echo "☸️  Deploying Kubernetes resources..."
kubectl apply -f kubernetes/primary/

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/sample-app

# Get LoadBalancer URL
echo "🌐 Getting LoadBalancer URL..."
kubectl get svc sample-app-service

echo "✅ Primary region deployment completed successfully!"

