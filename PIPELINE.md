# Wiki Service Deployment & Pipeline Guide

Deploy the Wiki API (FastAPI + PostgreSQL + Prometheus + Grafana) to Kubernetes using Helm. This guide covers deployment steps, local testing, and the CI pipeline.

## Components

1. **FastAPI** — REST API for users and posts, with `/metrics` endpoint
2. **PostgreSQL** — Data storage with asyncpg driver and SQLAlchemy
3. **Prometheus** — Scrapes metrics every 15 seconds
4. **Grafana** — Dashboard showing user/post creation rates (login: admin / admin)

## Prerequisites

- Kubernetes 1.28+ or k3d
- Helm 3.x
- Docker
- kubectl configured

## Deploy to Kubernetes

**1. Build the image:**

```powershell
docker build -t wiki-service:0.1.0 wiki-service/
```

For k3d (no registry):
```powershell
k3d image import wiki-service:0.1.0 -c your-cluster
```

For registry:
```powershell
docker tag wiki-service:0.1.0 your-registry/wiki-service:0.1.0
docker push your-registry/wiki-service:0.1.0
```

**2. Create namespace:**

```powershell
kubectl create namespace wiki-prod
```

**3. Install Helm chart:**

```powershell
helm install wiki-service ./wiki-chart \
  --namespace wiki-prod \
  --set fastapi.image.tag=0.1.0
```

**4. Check status:**

```powershell
kubectl get pods -n wiki-prod
kubectl get svc -n wiki-prod
```

Wait 2-3 minutes for pods to be ready.

**5. Access services:**

FastAPI:
```powershell
kubectl port-forward -n wiki-prod svc/wiki-service-wiki-chart-fastapi 8000:8000
curl http://localhost:8000/users
```

Grafana:
```powershell
kubectl port-forward -n wiki-prod svc/wiki-service-wiki-chart-grafana 3000:3000
# Open http://localhost:3000/d/creation-dashboard-678/creation
# Login: admin / (auto-generated password)
```

## Resource Usage

| Component   | CPU  | Memory | Storage |
|-------------|------|--------|---------|
| FastAPI     | 500m | 1Gi    | — |
| PostgreSQL  | 500m | 1Gi    | 2Gi |
| Prometheus  | 500m | 1Gi    | 2Gi |
| Grafana     | 200m | 256Mi  | 1Gi |
| **Total**   | 1.7  | 3.3Gi  | 5Gi |

Fits within 2 CPUs, 4GB RAM, 5GB disk limit.

## Get Auto-Generated Credentials

PostgreSQL and Grafana passwords are auto-generated on install. To retrieve them:

```powershell
# Postgres
kubectl get secret wiki-service-postgres-secret -n wiki-prod \
  -o jsonpath='{.data.password}' | base64 -d ; echo

# Grafana
kubectl get secret wiki-service-grafana-secret -n wiki-prod \
  -o jsonpath='{.data.admin-password}' | base64 -d ; echo
```

## Customize Deployment

Use `--set` to override `values.yaml`:

```powershell
# Increase storage
helm install wiki-service ./wiki-chart --namespace wiki-prod \
  --set postgresql.primary.persistence.size=10Gi

# Disable Grafana
helm install wiki-service ./wiki-chart --namespace wiki-prod \
  --set grafana.enabled=false --set prometheus.enabled=false
```

## CI Pipeline: Two Approaches

**Option 1: Independent Workflows (default)**

Each stage runs separately on push/PR:
- `python-quality.yml` — code quality & security
- `image-scan.yml` — Trivy vulnerability scan
- `helm-lint.yml` — Helm chart validation
- `integration-tests.yml` — k3d integration tests

Pros: quick feedback, easy to re-run single stage. Cons: need manual coordination.

**Option 2: Combined Pipeline**

One workflow runs all stages in order: `.github/workflows/ci-combined.yml`
- Stages chain with `needs` dependencies
- Later stages skip if earlier stage fails
- Full pipeline: quality → scan → helm-lint → integration

Pros: linear flow, gated deployment. Cons: longer runtime.

## Test Locally

**Quick check (2 min):**

```powershell
bash tests/helm-validate.sh
bash verify-pipeline-fixes.sh
```

**Full k3d test (10 min):**

```powershell
k3d cluster create test-wiki --image rancher/k3s:v1.31.13-k3s1
docker build -t wiki-service:test wiki-service/
k3d image import wiki-service:test -c test-wiki

kubectl create namespace test
helm install test-wiki ./wiki-chart --namespace test \
  --set fastapi.image.tag=test --set fastapi.image.pullPolicy=Never

kubectl get pods -n test -w
kubectl port-forward -n test svc/test-wiki-wiki-chart-fastapi 8000:8000
# Test: curl http://localhost:8000/users

k3d cluster delete test-wiki
```

## Troubleshooting

**CrashLoopBackOff:**
```powershell
kubectl logs -n wiki-prod wiki-service-postgres-0 --tail=50
kubectl logs -n wiki-prod <fastapi-pod> --tail=50
```
Check: storage class exists, Postgres is healthy, permissions on PVC.

**Helm install fails:**
Always use `--namespace`:
```powershell
helm install wiki-service ./wiki-chart --namespace wiki-prod
```

**Docker build fails in CI:**
```powershell
docker build wiki-service/ -t wiki-service:test
```
Check: `requirements.txt` syntax, relative paths, `COPY` instructions.

**Ingress not routing:**
```powershell
kubectl get ingress -n wiki-prod
kubectl get ingressclass
```
For k3d, Traefik is pre-installed. For cloud, install nginx-ingress.

## File Structure

```
wiki-service/
├─ main.py, database.py, models.py, schemas.py, metrics.py, test_api.py
├─ Dockerfile, requirements.txt

wiki-chart/
├─ Chart.yaml, values.yaml
└─ templates/
   ├─ fastapi.yaml, postgres.yaml, prometheus.yaml, grafana.yaml
   ├─ ingress.yaml, network-policy.yaml, _helpers.tpl

.github/workflows/
├─ python-quality.yml, image-scan.yml, helm-lint.yml, integration-tests.yml
└─ ci-combined.yml (single pipeline running all 4 stages in order)

tests/
├─ helm-validate.sh, integration-local.sh

PIPELINE.md — This guide
```

## Quick Commands

```powershell
# Deploy
docker build -t your-registry/wiki-service:0.1.0 wiki-service/
helm install wiki-service ./wiki-chart --namespace wiki-prod

# Check status
kubectl get pods -n wiki-prod
kubectl logs -n wiki-prod -l app=fastapi --tail=20

# Get passwords
kubectl get secret wiki-service-postgres-secret -n wiki-prod \
  -o jsonpath='{.data.password}' | base64 -d

# Uninstall
helm uninstall wiki-service --namespace wiki-prod
kubectl delete namespace wiki-prod
```
