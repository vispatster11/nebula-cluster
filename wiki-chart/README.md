# Wiki Service Helm Chart

A Helm chart for deploying the Wikipedia-like API service with PostgreSQL, Prometheus, and Grafana on Kubernetes.

## Components

- **FastAPI**: The main application service
- **PostgreSQL**: Database for data persistence
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboarding

## Prerequisites

- Kubernetes cluster (v1.19+)
- Helm 3.x
- NGINX Ingress Controller (for ingress)
- Docker image for FastAPI service built and available in your registry

## Installation

1. Build and push the FastAPI Docker image (pin the tag; do NOT use `latest`):

```bash
cd ../wiki-service
docker build -t your-registry/wiki-fastapi:0.1.0 .
docker push your-registry/wiki-fastapi:0.1.0
```

2. Update the image name in `values.yaml`:

```yaml
fastapi:
  image_name: "your-registry/wiki-fastapi:0.1.0"
```

3. Install the Helm chart:

```bash
helm install wiki-service . -n default
```

Or with custom image name:

```bash
helm install wiki-service . --set fastapi.image_name="your-registry/wiki-fastapi:0.1.0"
```

4. Verify the installation:

```bash
kubectl get pods
kubectl get svc
kubectl get ingress
```

## Access the Services

### FastAPI API
- http://localhost/users/
- http://localhost/posts/
- http://localhost/metrics

### Grafana Dashboard
- http://localhost/grafana/d/creation-dashboard-678/creation
- Username: `admin`
-- Password: auto-generated if `grafana.adminPassword` is empty; override via `--set grafana.adminPassword=...`

## Configuration

Key values in `values.yaml`:

- `fastapi.image_name`: Docker image name for FastAPI
- `fastapi.replicas`: Number of FastAPI replicas
- `postgresql.auth.password`: PostgreSQL password
- `grafana.adminPassword`: Grafana admin password
- `ingress.hosts`: Ingress host configuration

## Resource Limits

The chart is configured with the following resource allocations:

- **FastAPI**: 250m CPU / 512Mi RAM (requests), 500m CPU / 1Gi RAM (limits)
- **PostgreSQL**: 250m CPU / 512Mi RAM (requests), 500m CPU / 1Gi RAM (limits)
- **Prometheus**: 250m CPU / 512Mi RAM (requests), 500m CPU / 1Gi RAM (limits)
- **Grafana**: 100m CPU / 128Mi RAM (requests), 200m CPU / 256Mi RAM (limits)

**Total cluster requirements**: ~2 CPUs, 4GB RAM, 5GB disk

## Uninstall

```bash
helm uninstall wiki-service
```

## Troubleshooting

Check pod status:
```bash
kubectl get pods -o wide
kubectl logs <pod-name>
kubectl describe pod <pod-name>
```

Wait for PostgreSQL to be ready before FastAPI starts:
```bash
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s
```

## Dashboard Configuration

The dashboard at `/d/creation-dashboard-678/creation` displays:
- Users creation rate (5-minute average)
- Posts creation rate (5-minute average)
- Total users created (counter)
- Total posts created (counter)
