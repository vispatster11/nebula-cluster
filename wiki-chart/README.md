# Wiki Service Helm Chart

This Helm chart packages the entire Wiki API service stack for Kubernetes: a FastAPI application, PostgreSQL database, Prometheus monitoring, and Grafana dashboards.

## Prerequisites

- Kubernetes 1.28+
- Helm 3.x
- Docker
- `k3d` for creating local clusters

## Local Development and Testing

This project includes scripts to simplify local development and testing.

### 1. Validate the Chart (`helm-validate.sh`)

Before deploying, you can lint the chart and render its templates to a local file (`rendered-manifests.yaml`) to check for syntax errors and inspect the generated Kubernetes objects.

```bash
bash ./tests/helm-validate.sh
```

**2. Create namespace:**

```bash
kubectl create namespace wiki-prod
```

**3. Install chart:**

For k3d (local image):
```bash
helm install wiki-service . --namespace wiki-prod \
  --set fastapi.image.tag=0.1.0 \
  --set fastapi.image.pullPolicy=Never
```

For registry:
```bash
helm install wiki-service . --namespace wiki-prod \
  --set fastapi.image.repository=your-registry/wiki-service \
  --set fastapi.image.tag=0.1.0
```

**4. Verify:**

```bash
kubectl get pods -n wiki-prod
kubectl get svc -n wiki-prod
```

Wait 2-3 minutes for all pods to be ready.

## Customize

Use `--set` to override `values.yaml`:

```bash
# Change Grafana password
helm install wiki-service . --set grafana.adminPassword=MyPass

# Increase storage
helm install wiki-service . \
  --set postgresql.primary.persistence.size=10Gi \
  --set prometheus.storageSize=5Gi

# Disable Grafana
helm install wiki-service . \
  --set grafana.enabled=false \
  --set prometheus.enabled=false

# Change FastAPI replicas
helm install wiki-service . --set fastapi.replicas=3
```

See `values.yaml` for all options.

## Resource Usage

| Component | CPU Req | Memory Req | CPU Limit | Memory Limit | Storage |
|-----------|---------|------------|-----------|--------------|---------|
| FastAPI | 250m | 512Mi | 500m | 1Gi | — |
| PostgreSQL | 250m | 512Mi | 500m | 1Gi | 2Gi |
| Prometheus | 250m | 512Mi | 500m | 1Gi | 2Gi |
| Grafana | 100m | 128Mi | 200m | 256Mi | 1Gi |
| **Total** | 850m | 1.6Gi | 1.7 | 3.3Gi | 5Gi |

Fits within 2 CPUs, 4GB RAM, 5GB disk.

## Access Services

**FastAPI:**
```bash
kubectl port-forward -n wiki-prod svc/wiki-service-wiki-chart-fastapi 8000:8000
curl http://localhost:8000/users
```

**Grafana:**
```bash
kubectl port-forward -n wiki-prod svc/wiki-service-wiki-chart-grafana 3000:3000
# Open http://localhost:3000/d/creation-dashboard-678/creation
# Login: admin / (auto-generated password)
```

**Prometheus:**
```bash
kubectl port-forward -n wiki-prod svc/wiki-service-prometheus 9090:9090
# Open http://localhost:9090
```

## Get Credentials

```bash
# Postgres
kubectl get secret wiki-service-postgres-secret -n wiki-prod \
  -o jsonpath='{.data.password}' | base64 -d ; echo

# Grafana
kubectl get secret wiki-service-grafana-secret -n wiki-prod \
  -o jsonpath='{.data.admin-password}' | base64 -d ; echo
```

## Update Release

```bash
helm upgrade wiki-service . --namespace wiki-prod \
  --set grafana.adminPassword=NewPass \
  --set fastapi.replicas=3
```

## Uninstall

```bash
helm uninstall wiki-service --namespace wiki-prod
kubectl delete namespace wiki-prod
```

## Best Practices

1. Always use `--namespace` to keep deployments isolated
2. Set explicit passwords (don't rely on auto-generate)
3. Pin image tags (never use `:latest`)
4. Monitor with Grafana dashboards
5. Set resource requests/limits
6. Use external secret management (Vault, AWS Secrets Manager)

## Customizing the Deployment

The `values.yaml` file contains all configurable settings. Override them with `--set` flags:

### Common Customizations

**Change Grafana admin password:**

```bash
helm install wiki-service . --set grafana.adminPassword=MyPassword
```

**Increase storage sizes:**

```bash
helm install wiki-service . \
  --set postgresql.primary.persistence.size=10Gi \
  --set prometheus.storageSize=5Gi
```

**Disable Grafana** (keep just FastAPI + Postgres):

```bash
helm install wiki-service . \
  --set grafana.enabled=false \
  --set prometheus.enabled=false
```

**Change number of FastAPI replicas:**

```bash
helm install wiki-service . --set fastapi.replicas=3
```

See `values.yaml` for the complete list of options.

## Resource Allocation

The chart is designed to fit within strict resource constraints:

| Component  | CPU Requests | Memory Requests | CPU Limits | Memory Limits | Storage |
|------------|--------------|-----------------|------------|---------------|---------|
| FastAPI    | 250m         | 512Mi           | 500m       | 1Gi           | —       |
| PostgreSQL | 250m         | 512Mi           | 500m       | 1Gi           | 2Gi     |
| Prometheus | 250m         | 512Mi           | 500m       | 1Gi           | 2Gi     |
| Grafana    | 100m         | 128Mi           | 200m       | 256Mi         | 1Gi     |
| **Total**  | 850m         | 1664Mi          | 1700m      | 3.3Gi         | 5Gi     |

This stays well under the 2 CPUs, 4GB RAM, 5GB disk requirement.

## Accessing Services

### FastAPI

```bash
kubectl port-forward -n wiki-prod svc/wiki-service-wiki-chart-fastapi 8000:8000
curl http://localhost:8000/users
```

### Grafana Dashboard

```bash
kubectl port-forward -n wiki-prod svc/wiki-service-wiki-chart-grafana 3000:3000
```

Then open `http://localhost:3000/d/creation-dashboard-678/creation` and login with `admin` / `(your password)`.

The dashboard shows:
- **Users Created**: Counter and 5-minute rate
- **Posts Created**: Counter and 5-minute rate
- Real-time trends from the past hour

### Prometheus Metrics

```bash
kubectl port-forward -n wiki-prod svc/wiki-service-prometheus 9090:9090
```

Open `http://localhost:9090` to query metrics directly.

## Updating a Release

To change configuration after installation:

```bash
helm upgrade wiki-service . \
  --namespace wiki-prod \
  --set grafana.adminPassword=NewPassword \
  --set fastapi.replicas=3
```

## Uninstalling

```bash
helm uninstall wiki-service --namespace wiki-prod
kubectl delete namespace wiki-prod
```

## Chart Structure

```
wiki-chart/
├── Chart.yaml                      # Chart metadata (name, version)
├── values.yaml                     # Default configuration
├── README.md                        # This file
└── templates/
    ├── _helpers.tpl                # Shared template helpers
    ├── fastapi.yaml                # FastAPI Deployment, Service
    ├── postgres.yaml               # PostgreSQL StatefulSet, PVC, Secret
    ├── prometheus.yaml             # Prometheus ConfigMap, Deployment, PVC, RBAC
    ├── grafana.yaml                # Grafana Deployment, Service, Dashboard ConfigMaps
    ├── ingress.yaml                # Kubernetes Ingress for routing
    ├── network-policy.yaml         # Network policies (default-deny + allow rules)
    └── pdb-fastapi.yaml            # Pod Disruption Budget (for high availability)
```

## Troubleshooting

### Pods Stuck in CrashLoopBackOff

Check the logs:

```bash
kubectl logs -n wiki-prod wiki-service-postgres-0
kubectl logs -n wiki-prod <fastapi-pod-name>
```

**Common causes:**
- Storage class not found: `kubectl get storageclass`
- Database not ready: Wait 1-2 minutes
- Permission issues on PVC: Check if `fsGroup` matches the pod's UID

### FastAPI Can't Connect to Database

Postgres takes 30-60 seconds to initialize. FastAPI has an `initContainer` that polls `pg_isready` before starting the main application. Check that Postgres pod is running:

```bash
kubectl get pods -n wiki-prod -l app=postgres
```

### Helm Lint Errors

Validate the chart before installing:

```bash
helm lint . --strict
```

Fix any reported issues in the templates.

### Can't Access Grafana Dashboard

Ensure the `grafana.adminPassword` was set (auto-generated if empty). Retrieve it:

```bash
kubectl get secret wiki-service-grafana-secret -n wiki-prod \
  -o jsonpath='{.data.admin-password}' | base64 -d ; echo
```

## Best Practices

1. **Always specify a namespace**: Keeps deployments isolated
2. **Use persistent passwords**: Don't let Grafana auto-generate on every install
3. **Pin image tags**: Never use `:latest` in production
4. **Monitor metrics**: Use Grafana to catch issues early
5. **Set resource requests**: Helps Kubernetes schedule pods efficiently
6. **Keep secrets external**: Consider using HashiCorp Vault or AWS Secrets Manager instead of Kubernetes secrets

## Support

For issues or questions, check:
- Pod logs: `kubectl logs -n wiki-prod <pod-name>`
- Pod events: `kubectl describe pod -n wiki-prod <pod-name>`
- The main `../PIPELINE.md` guide for deployment steps
