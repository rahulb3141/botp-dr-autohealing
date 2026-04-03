#!/bin/bash
set -e

echo "🧹 Cleaning up test resources..."

# Scale down secondary region deployment
echo "📉 Scaling down secondary region deployment..."
kubectl scale deployment sample-app --replicas=1 --context=secondary-cluster || echo "Deployment not found or already scaled"

# Clean up any test pods or services
echo "🗑️  Cleaning up test resources..."
kubectl delete pods -l app=test --context=primary-cluster --ignore-not-found=true
kubectl delete pods -l app=test --context=secondary-cluster --ignore-not-found=true

# Clean up old log files (keep last 5)
echo "📋 Cleaning up old log files..."
if [ -d "logs" ]; then
    find logs -name "dr-test-*.log" -type f | sort -r | tail -n +6 | xargs rm -f
fi

echo "✅ Cleanup completed"

