#!/bin/bash
set -e

echo "🔄 Switching to DR region..."

# Scale up secondary region
echo "Scaling up secondary region..."
kubectl scale deployment sample-app --replicas=3 --context=secondary-cluster

# Wait for pods to be ready
echo "Waiting for DR pods to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/sample-app --context=secondary-cluster

# Update Route53 to point to secondary (manual step - would normally be automatic via health checks)
echo "Route53 will automatically failover based on health checks"
echo "Current DNS status:"
cd terraform/primary-region
ZONE_ID=$(terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="aws_route53_zone") | .values.zone_id' 2>/dev/null || echo "")
cd ../../

if [ -n "$ZONE_ID" ]; then
    aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" --query 'ResourceRecordSets[?Type==`CNAME`]' > logs/dns-failover-status.log
fi

# Verify secondary region is serving traffic
echo "Verifying secondary region..."
SECONDARY_ENDPOINT=$(kubectl get service sample-app-service --context=secondary-cluster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -n "$SECONDARY_ENDPOINT" ]; then
    echo "Secondary endpoint: $SECONDARY_ENDPOINT"
    curl -f "http://$SECONDARY_ENDPOINT/health" > logs/dr-health-check.log 2>&1 && echo "✅ DR region is healthy" || echo "❌ DR region health check failed"
fi

echo "✅ DR switch complete"
