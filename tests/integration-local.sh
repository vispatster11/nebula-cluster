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
# k3d cluster create "${CLUSTER_NAME}" --wait

echo "--- Building and loading Docker image: ${FULL_IMAGE_NAME} ---"
docker build -t "${FULL_IMAGE_NAME}" "${APP_PATH}"
# k3d image import "${FULL_IMAGE_NAME}" -c "${CLUSTER_NAME}"

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
helm test "${RELEASE_NAME}" --namespace "${NAMESPACE}" --logs --timeout 5m

# --- 4. Cleanup ---
echo "--- Cleaning up ---"
read -p "Press Enter to delete the k3d cluster..."
k3d cluster delete "${CLUSTER_NAME}"
rm -f rendered-manifests.yaml

echo "✓ Local test environment cleaned up."
