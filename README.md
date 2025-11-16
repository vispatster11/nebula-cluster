# Wiki Service - FastAPI + PostgreSQL + Prometheus + Grafana on Kubernetes

**Part 1:** FastAPI REST API with PostgreSQL, Prometheus metrics scraping, Grafana dashboard at `/d/creation-dashboard-678/creation` (admin:admin). Exposed via Ingress: `/users/*`, `/posts/*`, `/grafana/*`.

**Part 2:** Complete k3d cluster containerized via Docker with all components accessible on port 8080.

## Local Testing & Logs

### Run Integration Tests
```bash
bash tests/integration-local.sh
```

This script:
1. Creates k3d cluster (`local-cluster`)
2. Builds and loads wiki-service Docker image
3. Deploys Helm chart to `local-test` namespace
4. Runs helm test (integration tests)
5. Tests ingress endpoints via traefik port-forward
6. Outputs logs to `test-job-output.log`

### View Test Logs
```bash
# View logs (inside container)
kubectl -n local-test logs -l "app.kubernetes.io/component=test"

# Saved log file
cat test-job-output.log
```

### Manual Cluster Access
```bash
# Port-forward to traefik ingress
kubectl port-forward -n kube-system svc/traefik 8080:80

# Test endpoints
curl -H "Host: localhost" http://localhost:8080/                    # FastAPI root
curl -H "Host: localhost" http://localhost:8080/grafana/d/creation-dashboard-678/creation -u admin:admin
```


## Resources
FastAPI (500m/1Gi) + PostgreSQL (500m/1Gi) + Prometheus (500m/1Gi) + Grafana (200m/256Mi) = **1.7 CPU / 3.3GB RAM / 5GB disk** ✓

## Tests Status
✓ All 8 integration tests pass (helm test)
✓ Prometheus health endpoint working (network policy fix)
✓ Grafana dashboard provisioned and accessible
✓ Metrics collected and visualized
✓ Ingress routing all endpoints via traefik
