# Wiki Service

FastAPI + PostgreSQL + Prometheus + Grafana deployed to Kubernetes with Helm.

## Components

- `wiki-service/` — FastAPI REST API (users, posts, metrics)
- `wiki-chart/` — Helm chart for complete deployment
- `.github/workflows/` — CI/CD pipeline
- `Dockerfile` & `entrypoint.sh` — For running the entire cluster in a container (Part 2)

## CI Pipeline

This project uses a single, consolidated CI pipeline defined in `.github/workflows/ci-combined.yml`.

See `PIPELINE.md` for a detailed explanation of the pipeline structure and jobs.

## Getting Started

See `PIPELINE.md` for full deployment and testing guide.
