#!/bin/bash
set -e

echo "🧪 Starting DR failover test..."

# Create test log file
TEST_LOG="logs/dr-test-$(date +%Y%m%d-%H%M%S).log"
mkdir -p logs

{
    echo "DR Test Started: $(date)"
    echo "================================"
    
    # Test 1: Check primary cluster health
    echo "Test 1: Checking primary cluster health..."
    if kubectl get nodes --context=primary-cluster > /dev/null 2>&1; then
        echo "✅ Primary cluster is healthy"
    else
        echo "❌ Primary cluster is not accessible"
    fi
    
    # Test 2: Check secondary cluster health
    echo "Test 2: Checking secondary cluster health..."
    if kubectl get nodes --context=secondary-cluster > /dev/null 2>&1; then
        echo "✅ Secondary cluster is healthy"
    else
        echo "❌ Secondary cluster is not accessible"
        exit 1
    fi
    
    # Test 3: Deploy test application to secondary
    echo "Test 3: Deploying test application to secondary region..."
    kubectl apply -f kubernetes/secondary/ --context=secondary-cluster
    
    # Test 4: Wait for deployment
    echo "Test 4: Waiting for deployment to be ready..."
    if kubectl wait --for=condition=available --timeout=300s deployment/sample-app --context=secondary-cluster; then
        echo "✅ Deployment is ready in secondary region"
    else
        echo "❌ Deployment failed in secondary region"
        exit 1
    fi
    
    # Test 5: Check service endpoints
    echo "Test 5: Checking service endpoints..."
    kubectl get svc --context=secondary-cluster
    
    echo "================================"
    echo "DR Test Completed: $(date)"
    echo "✅ All tests passed successfully!"
    
} | tee "$TEST_LOG"

echo "📋 Test results saved to: $TEST_LOG"

