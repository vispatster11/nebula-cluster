# Wiki Service

FastAPI + PostgreSQL + Prometheus + Grafana deployed to Kubernetes with Helm.

## Components

- `wiki-service/` — FastAPI REST API (users, posts, metrics)
- `wiki-chart/` — Helm chart for complete deployment
- `.github/workflows/` — CI/CD pipeline

## CI Pipeline

Two options:

1. **Independent workflows** — Run separately on push/PR
   - `python-quality.yml`, `image-scan.yml`, `helm-lint.yml`, `integration-tests.yml`

2. **Combined pipeline** — Runs all stages in order
   - `.github/workflows/ci-combined.yml`
   - Stages: Python quality → Docker scan → Helm lint → Integration tests
   - Later stages skip if earlier stage fails

## Getting Started

See `PIPELINE.md` for full deployment and testing guide.

- **Deploy**: Build image, create namespace, `helm install wiki-service ./wiki-chart --namespace wiki-prod`
- **Dev**: See `wiki-service/README.md` for local setup
- **Ops**: See `wiki-chart/README.md` for Helm customization
- **CI**: See `PIPELINE.md` for pipeline details
