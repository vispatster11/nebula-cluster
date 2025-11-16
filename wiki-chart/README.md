# Wiki Service Helm Chart

Packages FastAPI, PostgreSQL, Prometheus, Grafana for Kubernetes.

## Chart Contents
- `templates/` — Kubernetes manifests (Deployments, StatefulSets, Services, Ingress, NetworkPolicies)
- `values.yaml` — Default configuration (image, resources, credentials, storage classes)
- `Chart.yaml` — Chart metadata

## Key Features
✓ FastAPI + PostgreSQL backend  
✓ Prometheus metrics scraping + Grafana dashboard (`/d/creation-dashboard-678/creation`)  
✓ Traefik Ingress routing (`/users/*`, `/posts/*`, `/grafana/*`)  
✓ NetworkPolicies for least-privilege access  
✓ Credentials stored in secrets
✓ Resource limits: 1.7 CPU, 3.3GB RAM, 5GB disk  

## Quick Install
```bash
helm install wiki-service . --namespace local-test \
  --set fastapi.image.tag=0.1.0 \
  --set fastapi.image.pullPolicy=Never \
  --set grafana.adminPassword=admin
```

See root `README.md` for full deployment steps and testing.

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

Ensure the `grafana.adminPassword` was set (see secret if empty). Retrieve it:

```bash
kubectl get secret wiki-service-grafana-secret -n wiki-prod \
  -o jsonpath='{.data.admin-password}' | base64 -d ; echo
```

## Best Practices

1. **Always specify a namespace**: Keeps deployments isolated
2. **Use persistent passwords**: Don't let Grafana generate a new password on every install
3. **Pin image tags**: Never use `:latest` in production
4. **Monitor metrics**: Use Grafana to catch issues early
5. **Set resource requests**: Helps Kubernetes schedule pods efficiently
6. **Keep secrets external**: Consider using HashiCorp Vault or AWS Secrets Manager instead of Kubernetes secrets

## Support

For issues or questions, check:
- Pod logs: `kubectl logs -n wiki-prod <pod-name>`
- Pod events: `kubectl describe pod -n wiki-prod <pod-name>`
