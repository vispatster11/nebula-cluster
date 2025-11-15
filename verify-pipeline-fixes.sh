#!/bin/bash
# Quick verification that all pipeline fixes are in place

echo "=== Pipeline Fixes Verification ==="
echo ""

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

PASSED=0
FAILED=0

check_file_content() {
    local file=$1
    local pattern=$2
    local description=$3
    
    if grep -q "$pattern" "$file"; then
        echo "✓ $description"
        ((PASSED++))
    else
        echo "✗ $description"
        echo "  File: $file"
        echo "  Pattern: $pattern"
        ((FAILED++))
    fi
}

echo "Checking GitHub Actions versions..."
check_file_content ".github/workflows/python-quality.yml" "upload-artifact@v4" "python-quality uses upload-artifact v4"
check_file_content ".github/workflows/image-scan.yml" "codeql-action/upload-sarif@v3" "image-scan uses codeql-action v3"
check_file_content ".github/workflows/integration-tests.yml" "k3s:latest" "integration-tests uses k3s:latest"

echo ""
echo "Checking Helm chart..."
check_file_content "wiki-chart/templates/networkpolicy.yaml" "kind: NetworkPolicy" "NetworkPolicy template exists"
check_file_content "wiki-chart/templates/networkpolicy.yaml" "app.kubernetes.io/name" "NetworkPolicy uses Helm selector labels"
check_file_content "wiki-chart/templates/networkpolicy.yaml" "port: 53" "NetworkPolicy allows DNS egress"

echo ""
echo "Checking documentation..."
check_file_content "PIPELINE_ERRORS_FIXED.md" "All pipeline errors fixed" "Pipeline fixes documented"

echo ""
echo "=== Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo "✓ All pipeline fixes verified!"
    echo ""
    echo "Next steps:"
    echo "  1. Monitor workflows at: https://github.com/vishal-patel-git/nebula-cluster/actions"
    echo "  2. Verify all 4 workflows pass:"
    echo "     - image-scan (Docker image security)"
    echo "     - helm-lint (Helm chart validation)"
    echo "     - python-quality (Code quality)"
    echo "     - integration-tests (Full deployment test)"
    exit 0
else
    echo ""
    echo "✗ Some fixes are missing!"
    exit 1
fi
