#!/bin/bash
# Integration test: Deploy Helm chart to Kubernetes and run the test Job

set -e

RELEASE_NAME="wiki-test"
NAMESPACE="wiki-test"
CHART_DIR="wiki-chart"

echo "=========================================="
echo "Helm Chart Integration Test"
echo "=========================================="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "✗ kubectl not found. Install kubectl to run integration tests."
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "✗ helm not found. Install helm to run integration tests."
    exit 1
fi

# Check cluster connectivity
echo "Checking Kubernetes cluster connectivity..."
if kubectl cluster-info > /dev/null 2>&1; then
    echo "✓ Kubernetes cluster is accessible"
else
    echo "✗ Cannot connect to Kubernetes cluster"
    exit 1
fi

echo ""

# Create test namespace
echo "Creating test namespace..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
echo "✓ Namespace $NAMESPACE ready"

echo ""

# Install Helm chart
echo "Installing Helm chart release '$RELEASE_NAME' into '$NAMESPACE'..."
if helm install "$RELEASE_NAME" "$CHART_DIR" \
    --namespace "$NAMESPACE" \
    --set fastapi.image.repository="wiki-service" \
    --set fastapi.image.tag="0.1.0" \
    --timeout 5m \
    > /tmp/helm-install.log 2>&1; then
    echo "✓ Helm chart installed successfully"
else
    echo "✗ Helm chart installation failed"
    cat /tmp/helm-install.log
    exit 1
fi

echo ""

# Wait for test Job to complete
echo "Waiting for test Job to complete (timeout: 2m)..."
if kubectl wait --for=condition=complete job/"$RELEASE_NAME-test" \
    --namespace "$NAMESPACE" \
    --timeout=120s > /dev/null 2>&1; then
    echo "✓ Test Job completed"
else
    echo "⚠ Test Job did not complete in time or failed"
fi

echo ""

# Retrieve test Job logs
echo "Test Job output:"
echo "--------------------------------------"
kubectl logs -n "$NAMESPACE" job/"$RELEASE_NAME-test" 2>/dev/null || echo "No logs available"
echo "--------------------------------------"

echo ""

# Check test Job status
TEST_JOB_STATUS=$(kubectl get job "$RELEASE_NAME-test" -n "$NAMESPACE" -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")
if [ "$TEST_JOB_STATUS" = "1" ]; then
    echo "✓ Test Job succeeded"
    TEST_PASSED=true
else
    echo "✗ Test Job failed"
    TEST_PASSED=false
fi

echo ""

# Cleanup: Option to remove test namespace
echo "To clean up, run:"
echo "  kubectl delete namespace $NAMESPACE"

echo ""

if [ "$TEST_PASSED" = true ]; then
    echo "=========================================="
    echo "✓ Integration test passed"
    echo "=========================================="
    exit 0
else
    echo "=========================================="
    echo "✗ Integration test failed"
    echo "=========================================="
    exit 1
fi
