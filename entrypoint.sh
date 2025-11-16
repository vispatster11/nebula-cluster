#!/bin/bash

set -e

# Configuration
K3D_CLUSTER_NAME="nebula-cluster"
K3D_REGISTRY_PORT="5000"
# FASTAPI image split into repository + tag to avoid using `latest`
FASTAPI_IMAGE_REPO="wiki-service"
FASTAPI_IMAGE_TAG="0.1.0"
NAMESPACE="default"
HELM_RELEASE="wiki"
STARTUP_TIMEOUT=120
POD_READY_TIMEOUT=300

# Color output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Step 1: Wait for Docker daemon to be ready
log_info "Waiting for Docker daemon to start..."
START_TIME=$(date +%s)
while ! docker ps > /dev/null 2>&1; do
    ELAPSED=$(($(date +%s) - START_TIME))
    if [ $ELAPSED -gt $STARTUP_TIMEOUT ]; then
        log_error "Docker daemon failed to start within ${STARTUP_TIMEOUT} seconds"
        exit 1
    fi
    echo -n "."
    sleep 2
done
log_success "Docker daemon is ready"

# Step 2: Build wiki-service Docker image
log_info "Building wiki-service Docker image..."
if docker build -t "$FASTAPI_IMAGE_REPO:$FASTAPI_IMAGE_TAG" ./wiki-service > /tmp/build.log 2>&1; then
    log_success "Built $FASTAPI_IMAGE_REPO:$FASTAPI_IMAGE_TAG"
else
    log_error "Failed to build image"
    tail -20 /tmp/build.log
    exit 1
fi

# Step 3: Create k3d cluster with LoadBalancer on port 8080
log_info "Creating k3d cluster: $K3D_CLUSTER_NAME..."
if k3d cluster create "$K3D_CLUSTER_NAME" \
    --servers 1 \
    --agents 0 \
    --port "8080:80@loadbalancer" \
    --wait \
    --image "ghcr.io/k3d-io/k3d:5.8.3-dind" \
    > /tmp/k3d-create.log 2>&1; then
    log_success "Created k3d cluster"
else
    log_error "Failed to create k3d cluster"
    tail -20 /tmp/k3d-create.log
    exit 1
fi

# Step 4: Import wiki-service image into k3d cluster
log_info "Importing $FASTAPI_IMAGE_REPO:$FASTAPI_IMAGE_TAG into k3d cluster..."
if k3d image import "$FASTAPI_IMAGE_REPO:$FASTAPI_IMAGE_TAG" -c "$K3D_CLUSTER_NAME" > /tmp/k3d-import.log 2>&1; then
    log_success "Imported image into k3d"
else
    log_error "Failed to import image"
    tail -20 /tmp/k3d-import.log
    exit 1
fi

# Step 5: Deploy Helm chart
log_info "Deploying Helm chart..."
if helm install "$HELM_RELEASE" ./wiki-chart \
    --set fastapi.image.repository="$FASTAPI_IMAGE_REPO" \
    --set fastapi.image.tag="$FASTAPI_IMAGE_TAG" \
    --set fastapi.image.pullPolicy="Never" \
    > /tmp/helm-install.log 2>&1; then
    log_success "Helm chart deployed"
else
    log_error "Failed to deploy Helm chart"
    tail -30 /tmp/helm-install.log
    kubectl get pods -o wide
    exit 1
fi

# Step 6: Wait for all pods to be ready
log_info "Waiting for pods to become Ready (timeout: ${POD_READY_TIMEOUT}s)..."
START_TIME=$(date +%s)
READY=0
while [ $READY -eq 0 ]; do
    ELAPSED=$(($(date +%s) - START_TIME))
    
    if [ $ELAPSED -gt $POD_READY_TIMEOUT ]; then
        log_error "Pods failed to become Ready within ${POD_READY_TIMEOUT} seconds"
        kubectl get pods -o wide
        exit 1
    fi
    
    # Check if all pods are ready
    TOTAL=$(kubectl get pods -o jsonpath='{.items | length}')
    READY=$(kubectl get pods -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep -c "True" || echo 0)
    
    if [ "$READY" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        log_success "All $TOTAL pods are Ready"
        break
    fi
    
    echo -n "."
    sleep 5
done

# Step 7: Display service status
log_info "Service Status:"
kubectl get all
log_success "FastAPI available at http://localhost:8080"
log_success "Grafana available at http://localhost:8080/grafana/"

# Step 8: Show credentials
log_info "Credentials:"
PG_PASSWORD=$(kubectl get secret "$HELM_RELEASE-postgres-secret" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "auto-generated")
log_info "PostgreSQL password: $PG_PASSWORD"

# Step 9: Health check - verify API is responsive
log_info "Performing health checks..."
MAX_RETRIES=10
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8080/ > /dev/null 2>&1; then
        log_success "API is responsive"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo -n "."
        sleep 2
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log_warn "API not immediately responsive, but cluster appears healthy"
fi

# Step 10: Final message and keep container alive
echo ""
log_success "Container ready. Use Ctrl+C to stop."
echo ""
echo "Quick test commands:"
echo "  curl -X POST http://localhost:8080/users -H 'Content-Type: application/json' -d '{\"name\": \"Test User\"}'"
echo "  curl http://localhost:8080/users/1"
echo "  curl http://localhost:8080/grafana/d/creation-dashboard-678/creation"
echo ""

# Check if DEBUG mode is enabled
if [ "$DEBUG" = "true" ]; then
    log_info "DEBUG mode enabled - tailing FastAPI logs..."
    kubectl logs -f -l app.kubernetes.io/name=wiki-chart-fastapi --all-containers --timestamps=true --tail=50 || sleep infinity
else
    # Keep container running
    sleep infinity
fi
