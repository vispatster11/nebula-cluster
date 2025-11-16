#!/bin/bash
#
# integration-local.sh: Runs a full local integration test using k3d.
#
# This script creates a k3d cluster, builds the app, deploys with Helm,
# runs tests, and cleans up. It mirrors the CI 'integration-test' job.
#
# This script should be run from the project root directory.
#

set -e

# --- Configuration ---
CHART_PATH="./wiki-chart"
APP_PATH="./wiki-service"
RELEASE_NAME="local-release"
NAMESPACE="local-test"
CLUSTER_NAME="local-cluster"
IMAGE_NAME="wiki-service"
IMAGE_TAG="local-$(date +%s)"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# --- 1. Pre-flight Validation ---
echo "--- Running Helm validation script ---"
bash ./tests/helm-validate.sh

# --- 2. Setup Local Environment ---
echo "--- Creating k3d cluster: ${CLUSTER_NAME} ---"
k3d cluster create "${CLUSTER_NAME}" --wait

echo "--- Building and loading Docker image: ${FULL_IMAGE_NAME} ---"
docker build -t "${FULL_IMAGE_NAME}" "${APP_PATH}"
k3d image import "${FULL_IMAGE_NAME}" -c "${CLUSTER_NAME}"

echo "--- Detecting default storage class ---"
DEFAULT_STORAGE_CLASS=$(kubectl get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')

if [ -z "$DEFAULT_STORAGE_CLASS" ]; then
  echo "::error:: No default storage class found in the cluster. Cannot proceed."
  exit 1
fi
echo "✓ Found default storage class: ${DEFAULT_STORAGE_CLASS}"

# --- 3. Deploy and Test ---
echo "--- Deploying application with Helm ---"
kubectl create namespace "${NAMESPACE}" || echo "Namespace ${NAMESPACE} already exists."
helm install "${RELEASE_NAME}" "${CHART_PATH}" \
  --namespace "${NAMESPACE}" \
  --set fastapi.image.tag="${IMAGE_TAG}" \
  --set fastapi.image.pullPolicy=Never \
  --set grafana.adminPassword=admin \
  --set postgresql.primary.persistence.storageClass="${DEFAULT_STORAGE_CLASS}" \
  --set prometheus.persistence.storageClass="${DEFAULT_STORAGE_CLASS}" \
  --set grafana.persistence.storageClass="${DEFAULT_STORAGE_CLASS}" \
  --wait --timeout 5m # Wait for deployments to be ready

echo "✓ Helm release '${RELEASE_NAME}' deployed."
echo "--- Pods in namespace ${NAMESPACE}: ---"
kubectl get pods -n "${NAMESPACE}"

echo "--- Running application tests (helm test) ---"
# Run helm test to execute the job, but don't stream logs directly, as it can be flaky.
# This command will wait for the job to complete and report success/failure.
helm test "${RELEASE_NAME}" --namespace "${NAMESPACE}" --timeout 5m

echo "--- Retrieving logs from test pod ---"
# Find the pod created by the test job using its unique label and get its logs.
# This is more reliable than `helm test --logs`.
POD_NAME=$(kubectl get pod -n "${NAMESPACE}" -l "app.kubernetes.io/component=test" -o jsonpath='{.items[0].metadata.name}')
if [ -n "$POD_NAME" ]; then
  kubectl logs -n "${NAMESPACE}" "$POD_NAME" | tee test-job-output.log
fi

echo "--- Testing Ingress Endpoints ---"
# Set up port forwarding to the k3d ingress controller's load balancer service
kubectl port-forward --namespace kube-system "service/k3d-${CLUSTER_NAME}-serverlb" 8080:80 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 5 # Allow time for port-forward to establish

BASE_URL="http://localhost:8080"

# Test 1: FastAPI root endpoint
echo "Testing FastAPI root endpoint..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" --connect-timeout 5 --max-time 10 -H "Host: localhost" "$BASE_URL/")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | awk -F: '{print $2}')
echo "Response Body: $(echo "$RESPONSE" | sed '$d')"
if [ "$HTTP_CODE" -eq 200 ]; then
  echo "✓ PASSED: FastAPI root is accessible via ingress with status 200."
else
  echo "✗ FAILED: Expected status 200 for FastAPI root, but got $HTTP_CODE."
  kill $PORT_FORWARD_PID
  exit 1
fi
echo ""

# Test 2: Grafana dashboard
echo "Testing Grafana dashboard access..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" --connect-timeout 5 --max-time 10 -H "Host: localhost" -u admin:admin "$BASE_URL/grafana/d/creation-dashboard-678/creation")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | awk -F: '{print $2}')
echo "Response Status: $HTTP_CODE"
if [ "$HTTP_CODE" -eq 200 ]; then
  echo "✓ PASSED: Grafana dashboard is accessible via ingress with status 200."
else
  echo "✗ FAILED: Expected status 200 for Grafana dashboard via ingress, but got $HTTP_CODE."
  kill $PORT_FORWARD_PID
  exit 1
fi

# Clean up the port-forward process
kill $PORT_FORWARD_PID

# --- 4. Cleanup ---
echo "--- Cleaning up ---"
read -p "Press Enter to delete the k3d cluster..."
k3d cluster delete "${CLUSTER_NAME}"
rm -f rendered-manifests.yaml

echo "✓ Local test environment cleaned up."
