#!/bin/bash
set -e

echo "🚀 Deploying DR environment (same region, different AZs)..."

echo "Setting up DR configuration..."
cd terraform/secondary-region
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
cd ../../

# Use the same EKS cluster
echo "Deploying DR applications to existing cluster..."
aws eks update-kubeconfig --region ${TF_VAR_primary_region:-us-east-1} --name eks-cluster

# Deploy DR applications from secondary directory
echo "Deploying DR applications..."
if [ -d "kubernetes/secondary" ]; then
    echo "Found secondary Kubernetes manifests, deploying..."
    kubectl apply -f kubernetes/secondary/
else
    echo "No secondary manifests found, creating sample deployment..."
    kubectl create deployment sample-app-dr --image=nginx:latest --replicas=2
    kubectl expose deployment sample-app-dr --port=80 --type=LoadBalancer
fi

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment --all || echo "⚠️ Deployment wait timed out, continuing..."

# Get service information
echo "Getting service information..."
mkdir -p logs
kubectl get services > logs/dr-services.log || true
kubectl get pods
kubectl get services

echo "✅ DR environment deployment complete"
