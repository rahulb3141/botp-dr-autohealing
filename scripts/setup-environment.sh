#!/bin/bash
set -e

echo "🔧 Setting up environment for DR demo..."

# Create logs directory
mkdir -p logs

# Check required tools
echo "Checking required tools..."
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform is required but not installed."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI is required but not installed."; exit 1; }

# Verify AWS access (using IAM role)
echo "Verifying AWS access..."
aws sts get-caller-identity > logs/aws-identity.log 2>&1
if [ $? -eq 0 ]; then
    echo "✅ AWS access verified"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ROLE_ARN=$(aws sts get-caller-identity --query Arn --output text)
    echo "Account ID: $ACCOUNT_ID"
    echo "Using Role: $ROLE_ARN"
else
    echo "❌ AWS access failed"
    exit 1
fi

# Set Terraform variables
export TF_VAR_project_name=${TF_VAR_project_name:-"dr-demo"}
export TF_VAR_primary_region=${TF_VAR_primary_region:-"us-east-1"}
export TF_VAR_secondary_region=${TF_VAR_secondary_region:-"us-west-2"}

# Verify regions are accessible
echo "Verifying region access..."
aws ec2 describe-regions --region $TF_VAR_primary_region --query 'Regions[0].RegionName' --output text > /dev/null 2>&1 && echo "✅ Primary region ($TF_VAR_primary_region) accessible"
aws ec2 describe-regions --region $TF_VAR_secondary_region --query 'Regions[0].RegionName' --output text > /dev/null 2>&1 && echo "✅ Secondary region ($TF_VAR_secondary_region) accessible"

echo "✅ Environment setup complete"
echo "Project: $TF_VAR_project_name"
echo "Primary Region: $TF_VAR_primary_region"
echo "Secondary Region: $TF_VAR_secondary_region"
