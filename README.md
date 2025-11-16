# Wiki Service

FastAPI + PostgreSQL + Prometheus + Grafana deployed to Kubernetes with Helm.

## Components

- `wiki-service/` — FastAPI REST API (users, posts, metrics)
- `wiki-chart/` — Helm chart for complete deployment
- `.github/workflows/` — CI/CD pipeline
- `Dockerfile` & `entrypoint.sh` — For running the entire cluster in a container (Part 2)

## CI Pipeline

This project provides two CI pipeline approaches:

1.  **Sequential Pipeline (`ci-1.yml`)**: Runs all jobs in order. Ideal for ensuring quality before merging a pull request.
2.  **Independent Workflows (`ci-2.yml` to `ci-5.yml`)**: Separate workflows for Python quality, image scanning, Helm linting, and integration tests. These provide fast, targeted feedback on specific code changes.

See `PIPELINE.md` for a detailed explanation of both approaches.

## Getting Started

See `PIPELINE.md` for full deployment and testing guide.
