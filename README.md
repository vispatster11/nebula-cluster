# Wiki Service

FastAPI + PostgreSQL + Prometheus + Grafana deployed to Kubernetes with Helm.

## Components

- `wiki-service/` — FastAPI REST API (users, posts, metrics)
- `wiki-chart/` — Helm chart for complete deployment
- `.github/workflows/` — CI/CD pipeline
- `Dockerfile` & `entrypoint.sh` — For running the entire cluster in a container (Part 2 assignment)

## CI Pipeline

A single, sequential pipeline is defined in `.github/workflows/ci-1.yml`. It runs code quality checks, security scans, and integration tests in order. If any step fails, the pipeline stops.

## Getting Started

See `PIPELINE.md` for full deployment and testing guide.
