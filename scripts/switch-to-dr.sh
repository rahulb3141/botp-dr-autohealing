#!/bin/bash
set -e

echo "🔄 Switching to disaster recovery region..."

# Check if secondary cluster is available
echo "🔍 Checking secondary cluster health..."
kubectl get nodes --context=secondary-cluster

# Scale up secondary region deployment
echo "📈 Scaling up secondary region deployment..."
kubectl scale deployment sample-app --replicas=3 --context=secondary-cluster

# Wait for pods to be ready
echo "⏳ Waiting for pods to be ready in secondary region..."
kubectl wait --for=condition=available --timeout=300s deployment/sample-app --context=secondary-cluster

# Update Route 53 to point to secondary region (simulation)
echo "🌐 Updating DNS to point to secondary region..."
echo "Note: In real scenario, Route 53 health checks would automatically failover"

# Verify secondary region is serving traffic
echo "✅ Verifying secondary region deployment..."
kubectl get svc sample-app-service --context=secondary-cluster

echo "🎉 Successfully switched to disaster recovery region!"

