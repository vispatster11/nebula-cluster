# Deployment Guide

## Prerequisites

- Kubernetes 1.28+ or k3d
- Helm 3.x
- Docker
- kubectl configured

**1. Build the Docker Image:**

```powershell
docker build -t wiki-service:0.1.0 wiki-service/
k3d image import wiki-service:0.1.0 -c <your-cluster-name>
```

**2. Create Namespace:**

```bash
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
```bash
kubectl port-forward -n wiki-prod svc/wiki-service-wiki-chart-grafana 3000:3000
# Open http://localhost:3000/d/creation-dashboard-678/creation
# Login: admin / (see secret for password)
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

## Get Credentials

PostgreSQL and Grafana passwords are generated on install. To retrieve them:

```bash
# Postgres
kubectl get secret wiki-service-postgres-secret -n wiki-prod \
  -o jsonpath='{.data.password}' | base64 -d ; echo

# Grafana
kubectl get secret wiki-service-grafana-secret -n wiki-prod \
  -o jsonpath='{.data.admin-password}' | base64 -d ; echo
```

## Customize Deployment

Use `--set` to override `values.yaml`:

```bash
# Increase storage
helm install wiki-service ./wiki-chart --namespace wiki-prod \
  --set postgresql.primary.persistence.size=10Gi

# Disable Grafana
helm install wiki-service ./wiki-chart --namespace wiki-prod \
  --set grafana.enabled=false --set prometheus.enabled=false
```

## Test Locally

**Quick check (2 min):**

```bash
bash tests/helm-validate.sh
```

**Full k3d test (10 min):**

```powershell
k3d cluster create test-wiki --image rancher/k3s:v1.29.11-k3s1
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


**Ingress not routing:**
```powershell
kubectl get ingress -n wiki-prod
kubectl get ingressclass
```
For k3d, Traefik is pre-installed. For cloud, install nginx-ingress.

tests/

## Quick Commands

```bash
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
