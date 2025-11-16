# Wiki Service Deployment & Pipeline Guide

This guide walks you through deploying the Wiki API service—a FastAPI-backed REST application for managing users and posts—onto Kubernetes using Helm. You'll also find details about the CI/CD pipeline that ensures code quality, security, and reliability before deployment.

## What's Inside

**Wiki Service** is a lightweight FastAPI application that exposes REST endpoints for user and post management. Behind the scenes:

- **FastAPI**: Serves `/users`, `/posts`, and `/metrics` endpoints with built-in Prometheus integration
- **PostgreSQL**: Stores data persistently using `asyncpg` async driver and SQLAlchemy ORM
- **Prometheus**: Scrapes metrics from FastAPI every 15 seconds
- **Grafana**: Visualizes the creation rate dashboards (admin / admin credentials)

All components package into a single Helm chart that deploys to any Kubernetes cluster.

## Before You Start

You'll need:
- A Kubernetes cluster (1.28+) or local k3d setup
- Helm 3.x installed
- Docker for building images
- `kubectl` configured to access your cluster

## Deploying with Helm

### Step 1: Build the Docker Image

From the repository root:

```powershell
cd wiki-service
docker build -t wiki-service:0.1.0 .
```

For **local k3d** environments (no registry):

```powershell
# Build and import directly into cluster
docker build -t wiki-service:0.1.0 wiki-service/
k3d image import wiki-service:0.1.0 -c your-cluster-name
```

For **production** (push to registry):

```powershell
docker tag wiki-service:0.1.0 your-registry.azurecr.io/wiki-service:0.1.0
docker push your-registry.azurecr.io/wiki-service:0.1.0
```

### Step 2: Create a Namespace

```powershell
kubectl create namespace wiki-prod
```

### Step 3: Install the Helm Chart

Basic install with auto-generated credentials:

```powershell
helm install wiki-service ./wiki-chart \
  --namespace wiki-prod \
  --set fastapi.image.tag=0.1.0
```

With custom image registry:

```powershell
helm install wiki-service ./wiki-chart \
  --namespace wiki-prod \
  --set fastapi.image.repository=your-registry/wiki-service \
  --set fastapi.image.tag=0.1.0 \
  --set fastapi.image.pullPolicy=IfNotPresent \
  --set grafana.adminPassword=MySecurePassword123
```

### Step 4: Verify the Deployment

```powershell
# Watch pod startup
kubectl get pods -n wiki-prod -w

# All should reach "Running" state within 2-3 minutes
kubectl get svc -n wiki-prod
```

### Step 5: Access the Application

**FastAPI endpoints:**

```powershell
kubectl port-forward -n wiki-prod svc/wiki-service-wiki-chart-fastapi 8000:8000

# In another terminal:
curl http://localhost:8000/           # API info
curl http://localhost:8000/users      # List users
curl http://localhost:8000/metrics    # Prometheus metrics
```

**Grafana dashboard:**

```powershell
kubectl port-forward -n wiki-prod svc/wiki-service-wiki-chart-grafana 3000:3000

# Open http://localhost:3000/d/creation-dashboard-678/creation
# Login: admin / (your password from Step 3)
```

## Resource Constraints

The chart is optimized to fit within strict resource limits:

| Component   | CPU    | Memory | Storage |
|-------------|--------|--------|---------|
| FastAPI     | 500m   | 1Gi    | —       |
| PostgreSQL  | 500m   | 1Gi    | 2Gi     |
| Prometheus  | 500m   | 1Gi    | 2Gi     |
| Grafana     | 200m   | 256Mi  | 1Gi     |
| **Total**   | 1700m  | 3.3Gi  | 5Gi     |

This leaves room for Kubernetes overhead while staying under the 2 CPUs, 4GB RAM, 5GB disk requirement.

## Auto-Generated Credentials

PostgreSQL and Grafana passwords are automatically generated on first install if you don't specify them. To retrieve them later:

```powershell
# Postgres password
kubectl get secret wiki-service-postgres-secret -n wiki-prod \
  -o jsonpath='{.data.password}' | base64 -d ; echo

# Grafana admin password
kubectl get secret wiki-service-grafana-secret -n wiki-prod \
  -o jsonpath='{.data.admin-password}' | base64 -d ; echo
```

Store these somewhere safe for future logins.

## Customizing the Deployment

Need to adjust something? Pass `--set` flags to override `values.yaml`:

```powershell
# Change storage size
helm install wiki-service ./wiki-chart \
  --namespace wiki-prod \
  --set postgresql.primary.persistence.size=10Gi

# Disable Grafana if you only want FastAPI + Postgres
helm install wiki-service ./wiki-chart \
  --namespace wiki-prod \
  --set grafana.enabled=false \
  --set prometheus.enabled=false
```

## CI/CD Pipeline Architecture

The repository uses a **sequential CI/CD pipeline** that ensures code quality before deployment. Stages run in strict order—if one fails, the pipeline stops immediately. No parallelization.

### Four-Stage Pipeline

**Stage 1: Python Code Quality & Security**

Before anything else, we validate the Python codebase:
- Syntax check with `py_compile`
- Security scanning with Bandit (detects common vulnerabilities)
- Dependency audit with pip-audit (checks for vulnerable packages)

If any issue is found, the pipeline stops here. No Docker image is built until the code passes.

**Stage 2: Docker Image Security Scan**

Once code quality passes, we build the Docker image and scan it with Trivy:
- Detects vulnerable OS packages and Python dependencies
- Uploads results to GitHub's Security tab
- Does not block the pipeline (vulnerabilities are logged but not fatal)

This stage only runs if Stage 1 passes.

**Stage 3: Helm Chart Validation**

After confirming the Docker image is safe, we validate the Helm chart:
- `helm lint --strict` checks template syntax
- Verifies all required Kubernetes resources exist
- Confirms security contexts are properly configured

This stage only runs if Stage 2 completes.

**Stage 4: Integration Tests**

Finally, we run the full integration test in a real k3d cluster:
- Spin up PostgreSQL and verify it's healthy
- Load the Docker image into k3d
- Deploy the Helm chart to a test namespace
- Hit all API endpoints to confirm they work
- Check Grafana dashboard is accessible

This stage only runs if Stage 3 passes. If all tests succeed, the pipeline is complete.

### Why Sequential?

Sequential execution means:
1. **Early failure detection**: Security issues caught before expensive testing
2. **Clear root cause**: You know exactly which stage failed (Python? Docker? Helm? Integration?)
3. **Fast feedback**: Developers get results in 5-10 minutes, not 30
4. **Reliability**: No race conditions or flaky parallel tests

## Local Testing Before Commit

Before pushing, validate locally:

### Quick Validation (2 minutes)

```powershell
bash tests/helm-validate.sh
bash verify-pipeline-fixes.sh
```

This checks:
- Helm chart template syntax
- Resource definitions
- Namespace configurations

### Full k3d Integration (10 minutes)

For deeper testing:

```powershell
# Create a test cluster
k3d cluster create test-wiki --image rancher/k3s:v1.31.13-k3s1

# Build image and load it
docker build -t wiki-service:test wiki-service/
k3d image import wiki-service:test -c test-wiki

# Deploy the chart
kubectl create namespace test
helm install test-wiki ./wiki-chart \
  --namespace test \
  --set fastapi.image.tag=test \
  --set fastapi.image.pullPolicy=Never

# Wait for pods to be ready
kubectl get pods -n test -w

# Test endpoints
kubectl port-forward -n test svc/test-wiki-wiki-chart-fastapi 8000:8000
curl http://localhost:8000/users

# Cleanup
k3d cluster delete test-wiki
```

## Troubleshooting

### Pods Stuck in CrashLoopBackOff

Check the logs:

```powershell
kubectl logs -n wiki-prod wiki-service-postgres-0 --tail=20
kubectl logs -n wiki-prod <fastapi-pod-name> --tail=20
```

Common causes:
- **Postgres won't start**: Check storage class exists (`kubectl get storageclass`)
- **FastAPI can't connect to DB**: Postgres pod not healthy yet (wait 1-2 min)
- **Permission denied on PVC**: Storage class misconfigured for your cluster

### Helm Install Fails with Namespace Errors

The chart uses `.Release.Namespace`, so always specify `--namespace`:

```powershell
helm install wiki-service ./wiki-chart --namespace wiki-prod
```

Not specifying a namespace defaults to your current kubectl context (usually `default`), which may fail if you don't have permissions there.

### Docker Build Fails in CI

Check the Dockerfile is valid locally:

```powershell
docker build wiki-service/ -t wiki-service:test
```

Common issues:
- `requirements.txt` has syntax errors or unavailable packages
- Hardcoded paths instead of relative paths
- Missing `COPY` instructions in Dockerfile

### Ingress Not Routing Traffic

Verify the ingress exists and is configured:

```powershell
kubectl get ingress -n wiki-prod
kubectl describe ingress -n wiki-prod wiki-service-ingress
```

Check your cluster has an ingress controller:

```powershell
kubectl get ingressclass
```

For k3d, Traefik is pre-installed. For cloud clusters, you may need to install nginx-ingress or another controller.

## File Structure

```
wiki-service/                       # FastAPI application
├── Dockerfile                      # Container image (Python 3.13, non-root user)
├── main.py                         # API endpoints: /users, /posts, /metrics
├── database.py                     # PostgreSQL connection with asyncpg
├── models.py                       # SQLAlchemy ORM models
├── schemas.py                      # Pydantic request/response schemas
├── metrics.py                      # Prometheus Counter objects
├── test_api.py                     # Integration tests
└── requirements.txt                # Python dependencies (FastAPI, SQLAlchemy, asyncpg, etc.)

wiki-chart/                         # Helm chart
├── Chart.yaml                      # Chart metadata (name, version)
├── values.yaml                     # Default configuration (image, replicas, resources)
└── templates/
    ├── fastapi.yaml                # FastAPI deployment, service, initContainer
    ├── postgres.yaml               # PostgreSQL statefulset, PVC, secret, service
    ├── prometheus.yaml             # Prometheus deployment, PVC, scrape config
    ├── grafana.yaml                # Grafana deployment, dashboard ConfigMaps, service
    ├── ingress.yaml                # Ingress routing /users, /posts, /metrics, /grafana
    ├── network-policy.yaml         # Kubernetes network policies (default-deny + allow rules)
    └── _helpers.tpl                # Helm template helpers (chart name, labels, password generation)

.github/workflows/                  # GitHub Actions CI/CD
├── python-quality.yml              # Stage 1: Code quality & security
├── image-scan.yml                  # Stage 2: Docker image scan (Trivy)
├── helm-lint.yml                   # Stage 3: Helm validation
├── integration-tests.yml           # Stage 4: k3d integration tests
└── ci-sequential.yml               # Master workflow (orchestrates all 4 stages)

tests/
├── helm-validate.sh                # Local Helm chart validation
└── helm-integrate.sh               # Local k3d integration setup

PIPELINE.md                         # This file
Dockerfile                          # Part 2 container (not used in pipeline)
```

## Quick Reference

**Deploy to production:**

```powershell
docker build -t your-registry/wiki-service:0.1.0 wiki-service/
docker push your-registry/wiki-service:0.1.0
helm install wiki-service ./wiki-chart \
  --namespace wiki-prod \
  --set fastapi.image.repository=your-registry/wiki-service
```

**Test locally:**

```powershell
bash tests/helm-validate.sh
bash verify-pipeline-fixes.sh
```

**Check status:**

```powershell
kubectl get pods -n wiki-prod
kubectl logs -n wiki-prod -l app=fastapi --tail=10
```

**Get credentials:**

```powershell
kubectl get secret wiki-service-postgres-secret -n wiki-prod \
  -o jsonpath='{.data.password}' | base64 -d
```

**Cleanup:**

```powershell
helm uninstall wiki-service --namespace wiki-prod
kubectl delete namespace wiki-prod
```

## Next Steps

1. **Deploy to your cluster**: Follow the "Deploying with Helm" section above
2. **Verify it's working**: Hit the endpoints or view the Grafana dashboard
3. **Check the pipeline**: Push a commit and watch GitHub Actions run through all four stages
4. **Monitor in production**: Use Grafana to track user and post creation rates
5. **Scale if needed**: Increase replicas or storage using Helm values

---

**Version**: 1.0.0 | **Last Updated**: November 2025

---

## Quick Overview

- Service: FastAPI-based Wikipedia-like API (users, posts)
- Database: PostgreSQL via `asyncpg` + SQLAlchemy Async
- Packaging: `wiki-chart/` Helm chart deploying FastAPI, Postgres, Prometheus, Grafana
- CI: GitHub Actions for image build/scan, Helm linting, Python security, and k3d-based integration

---

## CI & Pipeline Fixes (what changed)

- Upgraded and pinned GitHub Actions where appropriate (e.g., `upload-artifact@v4`, `codeql-action/upload-sarif@v4`).
- Trivy image scanning now produces SARIF output (uploaded to Security tab) and a human-readable table. Scans are non-fatal for pipeline stability while vulnerabilities remain visible.
- Helm lint workflow pinned to a reproducible Helm version; templates validated with `tests/helm-validate.sh`.
- Integration tests use `k3d` and import the locally-built image; the k3s image used for `k3d cluster create` is pinned to a stable `rancher/k3s` version to avoid upstream flakiness.
- **Namespace-agnostic templates**: All Kubernetes resources now use `.Release.Namespace` instead of hardcoded `default` or configurable `.Values.namespace`, ensuring proper multi-namespace deployments without requiring manual namespace configuration.
- **Cleaned up chart structure**: Removed duplicate `networkpolicy.yaml` file; kept single, well-defined `network-policy.yaml` with proper namespace and label selectors for verification scripts.

---

## Deployment Guide (Helm)

### Quick Start

Prerequisites: Kubernetes cluster, Helm 3.x, Docker.

1. Build and push the FastAPI Docker image (use pinned tag):

```powershell
cd wiki-service
docker build -t your-registry/wiki-fastapi:0.1.0 .
docker push your-registry/wiki-fastapi:0.1.0
```

2. Update `wiki-chart/values.yaml` or pass `--set` overrides to point to your image (avoid `:latest`).

3. Install the chart (specify a namespace or use default):

```powershell
cd wiki-chart
helm install wiki-service . --namespace wiki-prod
# or use default namespace:
helm install wiki-service .
```

4. Verify resources:

```powershell
kubectl get pods --namespace default
kubectl get svc --namespace default
kubectl get ingress --namespace default
```

---

## Credential Auto-Generation

- `wiki-chart` supports automatic credential generation for PostgreSQL and Grafana when values are left empty.
- Defaults in `values.yaml` set `postgresql.auth.password` and `grafana.adminPassword` to `""`.
- Helm helper `wiki-chart.getOrGeneratePassword` checks for a provided value, attempts to read an existing Secret, and otherwise generates a 32-char random password.
- To retrieve auto-generated credentials after install:

```powershell
kubectl get secret <release-name>-postgres-secret -o jsonpath='{.data.password}' | base64 -d
kubectl get secret <release-name>-grafana-secret -o jsonpath='{.data.admin-password}' | base64 -d
```

---

## Local Verification & Tests

- Run local quick checks to validate the chart and pipeline scripts:

```powershell
bash tests/helm-validate.sh
bash verify-pipeline-fixes.sh
```

- Integration workflow (in CI) performs:
  - Unit tests with a local PostgreSQL service
  - Docker image build and Trivy scan
  - k3d cluster creation and Helm install into `wiki-test` namespace
  - FastAPI endpoint checks and Grafana dashboard checks via port-forwarding

---

## Files & Workflows to Watch

- Helm chart: `wiki-chart/` (templates, values.yaml, helpers)
- FastAPI service: `wiki-service/` (Dockerfile, `database.py`, `main.py`)
- CI workflows: `.github/workflows/` (`image-scan.yml`, `helm-lint.yml`, `python-quality.yml`, `integration-tests.yml`)

---

## Troubleshooting Highlights

- If Helm installs fail, ensure `helm install --namespace <ns>` is specified. All Helm templates are namespace-agnostic and will automatically use the namespace provided at install time via `--namespace` flag (defaults to current kubectl context namespace if not specified).
- If k3d cluster creation fails in CI, verify the `rancher/k3s` image tag in `.github/workflows/integration-tests.yml` (we now use `rancher/k3s:v1.31.13-k3s1`).
- Verify no duplicate template files exist in `wiki-chart/templates/` and that all templates properly reference `.Release.Namespace` for namespace configuration.

---

## Appendix: Useful Commands

```powershell
# Run unit+integration tests locally (requires Docker)
bash .github/workflows/scripts/run-local-integration.sh || true

# Validate Helm templates locally
bash tests/helm-validate.sh

# Verify pipeline checks
bash verify-pipeline-fixes.sh
```

---

For more details, inspect the individual workflow and chart files under `.github/workflows/` and `wiki-chart/`.
