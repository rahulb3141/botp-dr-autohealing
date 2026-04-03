#!/bin/bash
set -e

echo "🔍 Validating backup systems..."

# Check S3 buckets exist
echo "📦 Checking S3 backup buckets..."
if aws s3 ls s3://your-app-backups-primary > /dev/null 2>&1; then
    echo "✅ Primary backup bucket exists"
else
    echo "❌ Primary backup bucket not found"
fi

if aws s3 ls s3://your-app-backups-secondary --region us-west-2 > /dev/null 2>&1; then
    echo "✅ Secondary backup bucket exists"
else
    echo "❌ Secondary backup bucket not found"
fi

# Check cross-region replication
echo "🔄 Checking cross-region replication..."
PRIMARY_OBJECTS=$(aws s3 ls s3://your-app-backups-primary --recursive | wc -l)
SECONDARY_OBJECTS=$(aws s3 ls s3://your-app-backups-secondary --recursive --region us-west-2 | wc -l)

echo "Primary bucket objects: $PRIMARY_OBJECTS"
echo "Secondary bucket objects: $SECONDARY_OBJECTS"

if [ "$PRIMARY_OBJECTS" -eq "$SECONDARY_OBJECTS" ]; then
    echo "✅ Cross-region replication is working"
else
    echo "⚠️  Cross-region replication may have issues"
fi

# Check EKS cluster backups (using kubectl)
echo "☸️  Checking Kubernetes cluster state..."
kubectl get deployments --all-namespaces --context=primary-cluster > logs/primary-cluster-state.log
kubectl get deployments --all-namespaces --context=secondary-cluster > logs/secondary-cluster-state.log

echo "✅ Backup validation completed"

