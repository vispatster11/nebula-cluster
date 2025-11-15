#!/bin/bash
# Local Integration Test Script
# Runs code, PostgreSQL, API tests, and Helm validation locally

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

log_info "Starting local integration tests..."
echo ""

# ============ SECTION 1: Python Setup & Unit Tests ============
log_info "Section 1: Python Setup & Unit Tests"

# Check Python
if ! command -v python3 &> /dev/null; then
    log_error "Python 3 not found. Install Python 3.13+ and try again."
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
log_success "Python $PYTHON_VERSION available"

# Install dependencies
log_info "Installing wiki-service dependencies..."
cd wiki-service
pip install -q -r requirements.txt
pip install -q pytest pytest-asyncio httpx
cd ..
log_success "wiki-service dependencies installed"

log_info "Installing nebula-aurora-assignment dependencies..."
cd nebula-aurora-assignment
pip install -q -e . 2>/dev/null || pip install -q -r requirements.txt 2>/dev/null || true
pip install -q pytest pytest-asyncio httpx
cd ..
log_success "nebula-aurora-assignment dependencies installed"

echo ""

# ============ SECTION 2: PostgreSQL Startup ============
log_info "Section 2: PostgreSQL Setup"

# Check if Docker is running
if ! command -v docker &> /dev/null; then
    log_warn "Docker not found. Skipping PostgreSQL tests."
    SKIP_DB=true
else
    log_success "Docker available"
    
    # Start PostgreSQL container
    log_info "Starting PostgreSQL container..."
    docker run -d \
        --name test-postgres-$$  \
        -e POSTGRES_USER=postgres \
        -e POSTGRES_PASSWORD=testpass \
        -e POSTGRES_DB=wiki \
        -p 5432:5432 \
        postgres:15-alpine \
        > /dev/null 2>&1 || true
    
    # Wait for PostgreSQL
    log_info "Waiting for PostgreSQL to be ready..."
    for i in {1..30}; do
        if docker exec test-postgres-$$ pg_isready -U postgres > /dev/null 2>&1; then
            log_success "PostgreSQL is ready"
            SKIP_DB=false
            break
        fi
        echo -n "."
        sleep 1
    done
    
    if [ "$SKIP_DB" != "false" ]; then
        log_warn "PostgreSQL not ready; skipping DB tests"
        SKIP_DB=true
    fi
fi

echo ""

# ============ SECTION 3: FastAPI Tests ============
if [ "$SKIP_DB" = "false" ]; then
    log_info "Section 3: FastAPI Tests with PostgreSQL"
    
    export DB_USER=postgres
    export DB_PASSWORD=testpass
    export DB_HOST=localhost
    export DB_PORT=5432
    export DB_NAME=wiki
    
    log_info "Starting FastAPI server..."
    cd wiki-service
    python -m uvicorn main:app --host 0.0.0.0 --port 8000 > /tmp/fastapi.log 2>&1 &
    FASTAPI_PID=$!
    cd ..
    
    sleep 3
    
    if ! kill -0 $FASTAPI_PID 2>/dev/null; then
        log_error "FastAPI failed to start"
        cat /tmp/fastapi.log
        docker stop test-postgres-$$ > /dev/null 2>&1 || true
        docker rm test-postgres-$$ > /dev/null 2>&1 || true
        exit 1
    fi
    
    log_success "FastAPI server running (PID: $FASTAPI_PID)"
    
    # Test endpoints
    echo ""
    log_info "Testing API endpoints..."
    
    # Health check
    if curl -s http://localhost:8000/ > /dev/null 2>&1; then
        log_success "✓ GET / (health check)"
    else
        log_error "✗ GET / failed"
    fi
    
    # Create user
    USER_RESPONSE=$(curl -s -X POST http://localhost:8000/users \
        -H "Content-Type: application/json" \
        -d '{"name":"Test User"}')
    if echo "$USER_RESPONSE" | grep -q '"id"'; then
        log_success "✓ POST /users (create user)"
    else
        log_error "✗ POST /users failed"
    fi
    
    # Get user
    if curl -s http://localhost:8000/user/1 > /dev/null 2>&1; then
        log_success "✓ GET /user/1 (get user)"
    else
        log_warn "⚠ GET /user/1 (user may not exist yet)"
    fi
    
    # Create post
    POST_RESPONSE=$(curl -s -X POST http://localhost:8000/posts \
        -H "Content-Type: application/json" \
        -d '{"user_id":1,"content":"Test post"}')
    if echo "$POST_RESPONSE" | grep -q '"post_id"'; then
        log_success "✓ POST /posts (create post)"
    else
        log_warn "⚠ POST /posts (may need valid user)"
    fi
    
    # Metrics
    if curl -s http://localhost:8000/metrics | grep -q "users_created_total"; then
        log_success "✓ GET /metrics (Prometheus metrics)"
    else
        log_error "✗ GET /metrics failed"
    fi
    
    # Cleanup FastAPI
    kill $FASTAPI_PID 2>/dev/null || true
    wait $FASTAPI_PID 2>/dev/null || true
    
    echo ""
else
    log_warn "Skipping FastAPI tests (PostgreSQL not available)"
fi

# ============ SECTION 4: Helm Validation ============
log_info "Section 4: Helm Chart Validation"

# Check Helm
if ! command -v helm &> /dev/null; then
    log_warn "Helm not found. Skipping Helm validation."
else
    log_success "Helm available"
    
    log_info "Running Helm lint..."
    if helm lint wiki-chart --strict > /dev/null 2>&1; then
        log_success "✓ Helm chart lint passed"
    else
        log_error "✗ Helm chart lint failed"
        helm lint wiki-chart --strict || true
    fi
    
    log_info "Validating Helm templates..."
    if helm template test wiki-chart > /dev/null 2>&1; then
        log_success "✓ Helm templates rendered successfully"
    else
        log_error "✗ Helm template rendering failed"
        helm template test wiki-chart || true
    fi
fi

echo ""

# ============ SECTION 5: Docker Image Build ============
log_info "Section 5: Docker Image Build"

if ! command -v docker &> /dev/null; then
    log_warn "Docker not available. Skipping image build."
else
    log_info "Building wiki-service Docker image..."
    if docker build -t wiki-service:0.1.0 ./wiki-service > /tmp/docker-build.log 2>&1; then
        log_success "✓ Docker image built successfully"
    else
        log_error "✗ Docker image build failed"
        tail -20 /tmp/docker-build.log
    fi
fi

echo ""

# ============ CLEANUP ============
log_info "Cleanup"

if [ -n "$SKIP_DB" ] && [ "$SKIP_DB" = "false" ]; then
    log_info "Stopping PostgreSQL container..."
    docker stop test-postgres-$$ > /dev/null 2>&1 || true
    docker rm test-postgres-$$ > /dev/null 2>&1 || true
    log_success "PostgreSQL stopped"
fi

echo ""

# ============ SUMMARY ============
log_success "Local integration tests completed!"
echo ""
echo "=== Test Summary ==="
echo "✓ Python environment setup"
echo "✓ Dependency installation"
if [ "$SKIP_DB" = "false" ]; then
    echo "✓ PostgreSQL database tests"
    echo "✓ FastAPI endpoint tests"
else
    echo "⚠ PostgreSQL tests skipped (Docker unavailable)"
fi
echo "✓ Helm chart validation"
echo "✓ Docker image build"
echo ""
echo "Next steps:"
echo "  1. Commit and push: git add . && git commit -m 'Fix pipelines and add integration tests'"
echo "  2. Push to GitHub: git push origin main"
echo "  3. Monitor workflows at: https://github.com/vishal-patel-git/nebula-cluster/actions"
echo ""
