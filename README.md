# Wiki Service Project

This repository contains a small production-like platform:

- `wiki-service/` — FastAPI application (API, async DB, Prometheus metrics)
- `wiki-chart/` — Helm chart to deploy FastAPI, PostgreSQL, Prometheus, Grafana
- CI workflows in `.github/workflows/` orchestrated by `ci-sequential.yml`

Quick links:

- Deployment & CI details: `PIPELINE.md`
- Service developer guide: `wiki-service/README.md`
- Helm chart operator guide: `wiki-chart/README.md`

How the CI runs:

- A single orchestrating workflow (`.github/workflows/ci-sequential.yml`) runs four stages in order:
  1. Python Code Quality & Security
  2. Docker Image Security Scan
  3. Helm Chart Validation
  4. Integration Tests (k3d)

If you need to run a specific stage locally, follow the instructions in `PIPELINE.md`.
