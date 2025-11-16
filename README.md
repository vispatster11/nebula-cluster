# Wiki Service

FastAPI + PostgreSQL + Prometheus + Grafana deployed to Kubernetes with Helm.

## Components

- `wiki-service/` — FastAPI REST API (users, posts, metrics)
- `wiki-chart/` — Helm chart for complete deployment
- `.github/workflows/` — CI/CD pipeline
- `Dockerfile` & `entrypoint.sh` — For running the entire cluster in Docker (Part 2)

## CI Pipeline

A single, sequential pipeline is defined in `.github/workflows/ci-1.yml`. It runs code quality checks, security scans, and integration tests in order. If any step fails, the pipeline stops.

## Getting Started

See `PIPELINE.md` for full deployment and testing guide.

- **Deploy**: Build image, create namespace, `helm install wiki-service ./wiki-chart --namespace wiki-prod`
- **Dev**: See `wiki-service/README.md` for local setup
- **Ops**: See `wiki-chart/README.md` for Helm customization
- **CI**: See `PIPELINE.md` for pipeline details
