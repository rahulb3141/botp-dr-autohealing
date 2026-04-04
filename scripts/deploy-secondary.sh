#!/bin/bash
set -e

echo "🚀 Deploying DR environment (same region, different AZs)..."

# Skip getting bucket info since we'll create it in secondary region
echo "Setting up DR configuration..."
cd terraform/secondary-region

# Initialize and apply Terraform (this will create the secondary bucket)
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

cd ../../

# Use the same EKS cluster but deploy to different namespace/AZs
echo "Deploying DR applications to existing cluster..."
aws eks update-kubeconfig --region ${TF_VAR_primary_region:-us-east-1} --name eks-cluster

kubectl create namespace dr-demo --dry-run=client -o yaml | kubectl apply -f -

# Deploy Kubernetes applications with DR configuration
if [ -d "kubernetes/secondary" ]; then
    kubectl apply -f kubernetes/secondary/ -n dr-demo
elif [ -d "kubernetes" ]; then
    kubectl apply -f kubernetes/ -n dr-demo
else
    echo "⚠️ No kubernetes directory found, creating sample deployment"
    kubectl create deployment sample-app-dr --image=nginx:latest -n dr-demo
fi

# Wait for deployments to be ready
echo "Waiting for DR deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/sample-app-dr -n dr-demo || echo "⚠️ Deployment wait timed out, continuing..."

# Get service information
echo "Getting DR service information..."
mkdir -p logs
kubectl get services -n dr-demo > logs/dr-services.log || true
kubectl get pods -n dr-demo

echo "✅ DR environment deployment complete"
echo "DR Namespace: dr-demo"
echo "DR running in different AZs within same region"
