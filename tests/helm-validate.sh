#!/bin/bash
# Validate Helm chart locally (lint + template rendering)

set -e

CHART_DIR="wiki-chart"

echo "=========================================="
echo "Helm Chart Validation Tests"
echo "=========================================="
echo ""

# Test 1: Helm lint
echo "Test 1: Running helm lint..."
if helm lint "$CHART_DIR"; then
    echo "✓ Helm lint passed"
else
    echo "✗ Helm lint failed"
    exit 1
fi

echo ""

# Test 2: Helm template rendering (dry-run)
echo "Test 2: Rendering Helm templates..."
if helm template wiki-release "$CHART_DIR" --namespace default > /tmp/helm-rendered.yaml; then
    echo "✓ Helm templates rendered successfully"
    echo "   Generated $(wc -l < /tmp/helm-rendered.yaml) lines of YAML"
else
    echo "✗ Helm template rendering failed"
    exit 1
fi

echo ""

# Test 3: Check for required resources
echo "Test 3: Validating required Kubernetes resources..."
RENDERED="/tmp/helm-rendered.yaml"

check_resource() {
    local kind=$1
    local name=$2
    if [ "$kind" = "NetworkPolicy" ]; then
        if grep -q "kind: $kind" "$RENDERED"; then
            echo "✓ $kind found"
            return 0
        else
            echo "✗ $kind not found"
            return 1
        fi
    else
        if grep -q "kind: $kind" "$RENDERED" && grep -q "name: .*$name" "$RENDERED"; then
            echo "✓ $kind $name found"
            return 0
        else
            echo "✗ $kind $name not found"
            return 1
        fi
    fi
}

check_resource "Service" "fastapi" || exit 1
check_resource "Deployment" "fastapi" || exit 1
check_resource "Service" "postgres" || exit 1
check_resource "Deployment" "postgres" || exit 1
check_resource "Service" "prometheus" || exit 1
check_resource "Deployment" "prometheus" || exit 1
check_resource "Service" "grafana" || exit 1
check_resource "Deployment" "grafana" || exit 1
check_resource "Secret" "postgres-secret" || exit 1
check_resource "Secret" "grafana-secret" || exit 1
check_resource "Ingress" "ingress" || exit 1
check_resource "NetworkPolicy" "networkpolicy" || exit 1
check_resource "PodDisruptionBudget" "pdb" || exit 1
check_resource "Job" "test" || exit 1

echo ""

# Test 4: Check for non-root security contexts
echo "Test 4: Validating security contexts (non-root)..."
if grep -q "runAsNonRoot: true" "$RENDERED"; then
    echo "✓ Non-root runAsNonRoot found in securityContext"
else
    echo "✗ Non-root runAsNonRoot not found"
    exit 1
fi

if grep -q "allowPrivilegeEscalation: false" "$RENDERED"; then
    echo "✓ allowPrivilegeEscalation: false found"
else
    echo "✗ allowPrivilegeEscalation: false not found"
    exit 1
fi

if grep -q "drop:" "$RENDERED" && grep -q "ALL" "$RENDERED"; then
    echo "✓ Capability drop found"
else
    echo "✗ Capability drop not found"
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ All Helm chart validation tests passed"
echo "=========================================="
