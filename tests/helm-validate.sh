#!/bin/bash
#
# helm-validate.sh: Lints and templates the Helm chart for pre-flight validation.
#
# This script should be run from the project root directory.
#

set -e

# --- Configuration ---
CHART_PATH="./wiki-chart"
RELEASE_NAME="local-release"
NAMESPACE="local-test"
OUTPUT_FILE="rendered-manifests.yaml"

echo "=========================================="
echo "Helm Chart Validation Tests"
echo "=========================================="

echo "--- 1. Linting Helm chart ---"
helm lint "${CHART_PATH}" --strict
echo "✓ Helm lint passed."

echo "--- 2. Templating Helm chart for inspection ---"
helm template "${RELEASE_NAME}" "${CHART_PATH}" \
  --namespace "${NAMESPACE}" \
  --set fastapi.image.tag="local" \
  --set fastapi.image.pullPolicy=Never \
  --set grafana.adminPassword=admin \
  > "${OUTPUT_FILE}"
echo "✓ Chart templates rendered to '${OUTPUT_FILE}'. Inspect this file to debug manifest issues."
