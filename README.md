# Nebula Aurora Assignment - Complete Kubernetes Cluster

**Complete Kubernetes cluster running FastAPI, PostgreSQL, Prometheus, and Grafana within a single Docker container using k3d and Docker-in-Docker.**

## Quick Start

### Build

```bash
docker build -t nebula-cluster .
```

**Build time:** ~30-60 seconds

### Run

```bash
docker run --privileged -p 8080:8080 nebula-cluster
```

**Startup time:** ~90-120 seconds. Wait for "Container ready. Use Ctrl+C to stop." message.

The `--privileged` flag is **mandatory** - it allows the container to run `dockerd` and manage the k3d cluster.

## Accessing Services

All services are accessible at `http://localhost:8080`:

### FastAPI Endpoints

```bash
# Create user
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe"}'

# Get user
curl http://localhost:8080/users/1

# Create post
curl -X POST http://localhost:8080/posts \
  -H "Content-Type: application/json" \
  -d '{"content": "Hello World", "user_id": 1}'

# Get post
curl http://localhost:8080/posts/1

# Get metrics (Prometheus format)
curl http://localhost:8080/metrics
```

### Grafana Dashboard

```
http://localhost:8080/grafana/d/creation-dashboard-678/creation
```

**Login Credentials:**

The dashboard visualizes user and post creation rates over time with 5-minute rolling windows.

## Requirements

### Software

### Docker Configuration

## Architecture

### Stack
  - **FastAPI** - Python 3.13, FastAPI 0.121.0, rate-limited, PostgreSQL async
  - **PostgreSQL** - Version 15-alpine (production-grade)
  - **Prometheus** - Version 2.48.0 (metrics scraping)
  - **Grafana** - Version 9.0.0 (dashboard visualization)

### Port Mapping

```
Host:8080 → Container:8080 → k3d LoadBalancer:80 → Traefik Ingress → Services
```

### Resource Limits

| Component  | CPU   | Memory | Storage   |
|------------|-------|--------|-----------|
| FastAPI    | 500m  | 1Gi    | -         |
| PostgreSQL | 500m  | 1Gi    | 2Gi PVC   |
| Prometheus | 500m  | 1Gi    | 2Gi PVC   |
| Grafana    | 200m  | 256Mi  | 1Gi PVC   |
| **Total**  | 1.75  | 3.25Gi | 5Gi       |

**Note:** Resource limits leave headroom (87.5% CPU, ~81% RAM, 100% storage) for dockerd, k3s system components, and build process overhead.

## Advanced Usage

### Debug Mode

Tail FastAPI logs in real-time:

```bash
docker run --privileged -p 8080:8080 -e DEBUG=true nebula-cluster
```

This streams application logs for troubleshooting.

# Nebula Aurora (Simple)

Short, human-friendly guide to build, run and test the full stack locally.

1) Build the single-container cluster image (requires Docker):

```powershell
cd 'C:\Users\vispa\OneDrive\Downloads\git\Personal\assi\1-GHCode'
docker build -t nebula-cluster .
```

2) Run the container (requires `--privileged`):

```powershell
docker run --privileged -p 8080:8080 nebula-cluster
```

Wait ~90–120s until you see: "Container ready. Use Ctrl+C to stop."

Service quick checks (after ready):

```powershell
# Create a user
curl -X POST http://localhost:8080/users -H "Content-Type: application/json" -d '{"name":"Alice"}'

# Create a post
curl -X POST http://localhost:8080/posts -H "Content-Type: application/json" -d '{"user_id":1,"content":"Hello"}'

# Metrics
curl http://localhost:8080/metrics

# Grafana dashboard (open in browser)
# http://localhost:8080/grafana/d/creation-dashboard-678/creation  (user: admin / admin)
```

Notes:
- `--privileged` is required for Docker-in-Docker used by the container.
- If you prefer iterative development, see `QUICKSTART.md` for a short k3d dev flow.

That's it — minimal and human-friendly. If you want I can also trim or combine other docs into a single short file.
  nebula-cluster
