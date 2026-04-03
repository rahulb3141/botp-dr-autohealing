#!/bin/bash
set -e

echo "🔧 Setting up environment for DR testing..."

# Check required tools
echo "🔍 Checking required tools..."

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Please install Terraform"
    exit 1
fi

echo "✅ All required tools are available"

# Create necessary directories
mkdir -p logs
mkdir -p terraform/primary-region/.terraform
mkdir -p terraform/secondary-region/.terraform

# Check AWS credentials
echo "🔑 Checking AWS credentials..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    echo "✅ AWS credentials are configured"
else
    echo "❌ AWS credentials not configured. Please run 'aws configure'"
    exit 1
fi

echo "✅ Environment setup completed"

