#!/bin/bash
set -e

echo "🧹 Cleaning up DR demo resources..."

# Cleanup Kubernetes resources
echo "Cleaning up Kubernetes resources..."
kubectl delete -f kubernetes/primary/ --context=primary-cluster --ignore-not-found=true || true
kubectl delete -f kubernetes/secondary/ --context=secondary-cluster --ignore-not-found=true || true

# Cleanup Terraform resources (secondary first)
echo "Destroying secondary region infrastructure..."
cd terraform/secondary-region
terraform destroy -auto-approve || true
cd ../primary-region

echo "Destroying primary region infrastructure..."
terraform destroy -auto-approve || true
cd ../../

# Cleanup local files
echo "Cleaning up local files..."
rm -f terraform/primary-region/tfplan
rm -f terraform/secondary-region/tfplan
rm -f terraform/primary-region/.terraform.lock.hcl
rm -f terraform/secondary-region/.terraform.lock.hcl
rm -rf terraform/primary-region/.terraform
rm -rf terraform/secondary-region/.terraform

# Cleanup kubectl contexts
echo "Cleaning up kubectl contexts..."
kubectl config delete-context primary-cluster 2>/dev/null || true
kubectl config delete-context secondary-cluster 2>/dev/null || true

echo "✅ Cleanup complete"
