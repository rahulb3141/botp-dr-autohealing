#!/bin/bash
set -e

echo "🧪 Testing disaster recovery failover..."

# Test primary region health
echo "Testing primary region health..."
PRIMARY_ENDPOINT=$(kubectl get service sample-app-service --context=primary-cluster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -n "$PRIMARY_ENDPOINT" ]; then
    echo "Primary endpoint: $PRIMARY_ENDPOINT"
    curl -f "http://$PRIMARY_ENDPOINT/health" > logs/primary-health.log 2>&1 || echo "Primary health check failed"
fi

# Test secondary region health
echo "Testing secondary region health..."
SECONDARY_ENDPOINT=$(kubectl get service sample-app-service --context=secondary-cluster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -n "$SECONDARY_ENDPOINT" ]; then
    echo "Secondary endpoint: $SECONDARY_ENDPOINT"
    curl -f "http://$SECONDARY_ENDPOINT/health" > logs/secondary-health.log 2>&1 || echo "Secondary health check failed"
fi

# Test S3 replication
echo "Testing S3 cross-region replication..."
cd terraform/primary-region
PRIMARY_BUCKET=$(terraform output -raw primary_backup_bucket 2>/dev/null || echo "")
SECONDARY_BUCKET=$(terraform output -raw secondary_backup_bucket 2>/dev/null || echo "")
cd ../../

if [ -n "$PRIMARY_BUCKET" ] && [ -n "$SECONDARY_BUCKET" ]; then
    # Create test file
    echo "Test backup file $(date)" > test-backup.txt
    
    # Upload to primary bucket
    aws s3 cp test-backup.txt "s3://$PRIMARY_BUCKET/test-backup.txt"
    
    # Wait for replication
    echo "Waiting for cross-region replication..."
    sleep 30
    
    # Check if replicated to secondary
    aws s3 ls "s3://$SECONDARY_BUCKET/test-backup.txt" --region ${TF_VAR_secondary_region:-us-west-2} > logs/replication-test.log 2>&1 && echo "✅ S3 replication working" || echo "❌ S3 replication failed"
    
    # Cleanup test file
    rm -f test-backup.txt
fi

# Test Route53 health checks
echo "Testing Route53 health checks..."
cd terraform/primary-region
HEALTH_CHECK_ID=$(terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="aws_route53_health_check" and .name=="primary") | .values.id' 2>/dev/null || echo "")
cd ../../

if [ -n "$HEALTH_CHECK_ID" ]; then
    aws route53 get-health-check --health-check-id "$HEALTH_CHECK_ID" > logs/health-check-status.log 2>&1 || echo "Health check query failed"
fi

# Test Kubernetes auto-healing
echo "Testing Kubernetes auto-healing..."
kubectl delete pod -l app=sample-app --context=primary-cluster --grace-period=0 --force 2>/dev/null || true
sleep 10
kubectl get pods -l app=sample-app --context=primary-cluster > logs/auto-healing-test.log

# Test HPA scaling
echo "Testing Horizontal Pod Autoscaler..."
kubectl get hpa --context=primary-cluster > logs/hpa-status.log

echo "✅ Disaster recovery tests complete"
