# Wiki API Service - Deployment Guide

## Overview

This project provides a complete productionization setup for a Wikipedia-like API service with FastAPI, PostgreSQL, Prometheus, and Grafana running on Kubernetes using Helm.

## Project Structure

```
├── wiki-service/              # FastAPI application with Docker packaging
│   ├── Dockerfile            # Multi-stage Docker build for FastAPI
│   ├── main.py              # FastAPI application endpoints
│   ├── database.py          # PostgreSQL configuration
│   ├── models.py            # SQLAlchemy database models (User, Post)
│   ├── schemas.py           # Pydantic request/response schemas
│   ├── metrics.py           # Prometheus metrics (users/posts counters)
│   ├── requirements.txt      # Python dependencies
│   ├── README.md            # Service documentation
│   ├── .dockerignore        # Docker build exclusions
│   └── .gitignore           # Git exclusions
│
└── wiki-chart/               # Helm chart for Kubernetes deployment
    ├── Chart.yaml           # Helm chart metadata
    ├── values.yaml          # Configuration values (environment variables)
    ├── README.md            # Helm chart documentation
    ├── templates/           # Kubernetes resource templates
    │   ├── _helpers.tpl     # Helm template functions
    │   ├── fastapi.yaml     # FastAPI deployment & service
    │   ├── postgres.yaml    # PostgreSQL deployment & service
    │   ├── postgres-secret.yaml # PostgreSQL credentials secret
    │   ├── prometheus.yaml  # Prometheus deployment & service
    │   ├── prometheus-rbac.yaml # Prometheus RBAC configuration
    │   ├── grafana.yaml     # Grafana deployment & service
    │   ├── grafana-secret.yaml  # Grafana admin credentials
    │   ├── grafana-dashboard-provider.yaml  # Dashboard provisioning
    │   └── ingress.yaml     # Kubernetes ingress routes
    └── files/               # Additional configuration files
```

## Quick Start

### Prerequisites

- Kubernetes cluster (v1.19+)
- Helm 3.x
- Docker (for building the FastAPI image)
- NGINX Ingress Controller installed in your cluster

### Step 1: Build and Push FastAPI Docker Image (pin tag)

```bash
cd wiki-service
docker build -t your-registry/wiki-fastapi:0.1.0 .
docker push your-registry/wiki-fastapi:0.1.0
```

### Step 2: Update Helm Values

Edit `wiki-chart/values.yaml` to set your Docker image (avoid `latest`):

```yaml
fastapi:
  image_name: "your-registry/wiki-fastapi:0.1.0"
```

### Step 3: Install Helm Chart

```bash
cd wiki-chart
helm install wiki-service . --namespace default
```

Or with custom values:

```bash
helm install wiki-service . \
  --set fastapi.image_name="your-registry/wiki-fastapi:0.1.0" \
  --set grafana.adminPassword="your-secure-password"
```

### Step 4: Verify Installation

```bash
# Check all pods are running
kubectl get pods

# Check services
kubectl get svc

# Check ingress
kubectl get ingress

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s
```

## Accessing Services

Once deployed, access the services through your ingress:

- **FastAPI API**: `http://your-domain/`
  - Create user: `POST /users`
  - Create post: `POST /posts`
  - Get metrics: `GET /metrics`

- **Grafana Dashboard**: `http://your-domain/grafana/d/creation-dashboard-678/creation`
  - Username: `admin`
  - Password: `admin` (or your configured password)

- **Prometheus**: `http://your-domain/prometheus` (if exposed via ingress)

## Database Configuration

### PostgreSQL

- **Default username**: `postgres`
- **Default password**: `postgres` (change in `postgres-secret.yaml`)
- **Default database**: `wiki`
- **Storage**: 2Gi PersistentVolume

The FastAPI service connects using environment variables from the PostgreSQL secret.

## Prometheus Metrics

The FastAPI service exposes the following metrics:

- `users_created_total` - Counter of total users created
- `posts_created_total` - Counter of total posts created

Prometheus scrapes these metrics every 15 seconds from `/metrics` endpoint.

## Grafana Dashboard

A pre-configured dashboard (`creation-dashboard-678`) displays:

1. **Users Creation Rate** - 5-minute rolling average of users created per second
2. **Posts Creation Rate** - 5-minute rolling average of posts created per second
3. **Total Users Created** - Total counter value
4. **Total Posts Created** - Total counter value

The dashboard automatically updates every 10 seconds.

## Resource Allocation

The entire system is configured for minimal resource usage:

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| FastAPI | 250m | 512Mi | 500m | 1Gi |
| PostgreSQL | 250m | 512Mi | 500m | 1Gi |
| Prometheus | 250m | 512Mi | 500m | 1Gi |
| Grafana | 100m | 128Mi | 200m | 256Mi |
| **Total** | **850m** | **1.664Gi** | **1700m** | **3.256Gi** |

**Cluster Requirements**: ~2 CPUs, 4GB RAM, 5GB disk (includes OS and other services)

## Storage Requirements

| Service | Size | Type |
|---------|------|------|
| PostgreSQL Data | 2Gi | ReadWriteOnce |
| Prometheus Data | 2Gi | ReadWriteOnce |
| Grafana Data | 1Gi | ReadWriteOnce |
| **Total** | **5Gi** | - |

## Customization

### Change Grafana Admin Password

Edit `wiki-chart/values.yaml`:

```yaml
grafana:
  adminPassword: "your-new-secure-password"
```

### Change PostgreSQL Password

Edit `wiki-chart/values.yaml`:

```yaml
postgresql:
  auth:
    password: "your-new-secure-password"
```

### Add More Grafana Dashboards

Edit `wiki-chart/templates/grafana.yaml` and add dashboard JSON to the ConfigMap.

### Adjust Resource Limits

Edit `wiki-chart/values.yaml` for each service's `resources` section.

## Monitoring and Debugging

### Check Pod Logs

```bash
kubectl logs <pod-name>

# Follow logs
kubectl logs -f <pod-name>

# Check specific container
kubectl logs <pod-name> -c <container-name>
```

### Describe Pod Issues

```bash
kubectl describe pod <pod-name>
```

### Check Persistent Volumes

```bash
kubectl get pvc
kubectl describe pvc <pvc-name>
```

### Test Database Connection

```bash
kubectl exec -it <postgres-pod> -- psql -U postgres -d wiki
```

### Check Prometheus Targets

Access Prometheus UI and navigate to `/targets` to verify FastAPI scraping.

## Scaling

### Scale FastAPI Replicas

```bash
helm upgrade wiki-service . --set fastapi.replicas=3
```

### Scale Prometheus Replicas

```bash
helm upgrade wiki-service . --set prometheus.replicas=2
```

## Uninstall

```bash
helm uninstall wiki-service --namespace default
```

This will remove all resources created by the chart.

## Troubleshooting

### FastAPI can't connect to PostgreSQL

- Ensure PostgreSQL pod is running: `kubectl get pods -l app=postgres`
- Check FastAPI environment variables: `kubectl exec <fastapi-pod> -- env | grep DB_`
- Check network connectivity: `kubectl logs <fastapi-pod>`

### Grafana shows no data

- Check Prometheus target status in Prometheus UI
- Verify FastAPI metrics endpoint: `curl http://<fastapi-svc>:8000/metrics`
- Check Grafana datasource configuration

### Ingress not routing traffic

- Verify NGINX Ingress Controller is installed
- Check ingress configuration: `kubectl describe ingress <ingress-name>`
- Test ingress rules: `kubectl get ingress`

## API Usage Examples

### Create a User

```bash
curl -X POST http://localhost/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe"}'
```

### Create a Post

```bash
curl -X POST http://localhost/posts \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "content": "Hello, World!"}'
```

### Get User

```bash
curl http://localhost/user/1
```

### Get Post

```bash
curl http://localhost/posts/1
```

### Get Metrics

```bash
curl http://localhost/metrics
```

## Performance Considerations

1. **Database Indexing**: Ensure indexes exist on foreign keys for optimal query performance
2. **Connection Pooling**: SQLAlchemy async session factory handles connection pooling
3. **Caching**: Consider adding Redis for caching frequently accessed data
4. **Rate Limiting**: Consider implementing rate limiting in FastAPI
5. **Load Balancing**: Increase FastAPI replicas for high traffic

## Security Considerations

1. **Secrets Management**: Use Kubernetes secrets for database and Grafana passwords
2. **RBAC**: The chart includes RBAC configuration for Prometheus
3. **Network Policies**: Consider adding network policies to restrict traffic
4. **TLS/SSL**: Configure TLS certificates for the ingress
5. **Database Security**: Change default PostgreSQL password in production
6. **Least Privilege**: All components use namespace-scoped Roles and dedicated ServiceAccounts where possible. FastAPI runs as a non-root user and containers drop capabilities.
7. **Image Vulnerability Management**: Integrate an image scanning step in CI using tools like `trivy`, `clair`, or `snyk`. Pin images by digest (`repository@sha256:...`) in `values.yaml` for immutability.
8. **Runtime Protection**: Consider deploying runtime security agents such as Falco (for behavioral intrusion detection) and enabling a workload policy enforcement (e.g., OPA/Gatekeeper) to prevent suspicious activities.
9. **Pod Security Standards**: Deploy to a namespace enforcing `pod-security.kubernetes.io/enforce: restricted` and test workloads against the `restricted` profile.

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review Kubernetes pod logs
3. Verify all prerequisites are installed
4. Check that your Docker image was built successfully
