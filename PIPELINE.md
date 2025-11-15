# Pipeline & Deployment Guide (Consolidated)

This repository contains a production-like FastAPI service packaged as a Helm chart with PostgreSQL, Prometheus, and Grafana. This single `PIPELINE.md` consolidates the project's deployment instructions, CI pipeline details, credential auto-generation notes, and verification steps.

## Contents
- Quick overview
- CI and pipeline fixes
- Deployment guide (Helm)
- Credential auto-generation
- Local validation and testing
- Files and workflows to watch

---

## Quick Overview

- Service: FastAPI-based Wikipedia-like API (users, posts)
- Database: PostgreSQL via `asyncpg` + SQLAlchemy Async
- Packaging: `wiki-chart/` Helm chart deploying FastAPI, Postgres, Prometheus, Grafana
- CI: GitHub Actions for image build/scan, Helm linting, Python security, and k3d-based integration

---

## CI & Pipeline Fixes (what changed)

- Upgraded and pinned GitHub Actions where appropriate (e.g., `upload-artifact@v4`, `codeql-action/upload-sarif@v4`).
- Trivy image scanning now produces SARIF output (uploaded to Security tab) and a human-readable table. Scans are non-fatal for pipeline stability while vulnerabilities remain visible.
- Helm lint workflow pinned to a reproducible Helm version; templates validated with `tests/helm-validate.sh`.
- Integration tests use `k3d` and import the locally-built image; the k3s image used for `k3d cluster create` is pinned to a stable `rancher/k3s` version to avoid upstream flakiness.
- NetworkPolicy and other Kubernetes templates updated to be namespace-agnostic and to use label selectors that verification scripts expect.

---

## Deployment Guide (Helm)

### Quick Start

Prerequisites: Kubernetes cluster, Helm 3.x, Docker.

1. Build and push the FastAPI Docker image (use pinned tag):

```powershell
cd wiki-service
docker build -t your-registry/wiki-fastapi:0.1.0 .
docker push your-registry/wiki-fastapi:0.1.0
```

2. Update `wiki-chart/values.yaml` or pass `--set` overrides to point to your image (avoid `:latest`).

3. Install the chart:

```powershell
cd wiki-chart
helm install wiki-service . --namespace default
```

4. Verify resources:

```powershell
kubectl get pods --namespace default
kubectl get svc --namespace default
kubectl get ingress --namespace default
```

---

## Credential Auto-Generation

- `wiki-chart` supports automatic credential generation for PostgreSQL and Grafana when values are left empty.
- Defaults in `values.yaml` set `postgresql.auth.password` and `grafana.adminPassword` to `""`.
- Helm helper `wiki-chart.getOrGeneratePassword` checks for a provided value, attempts to read an existing Secret, and otherwise generates a 32-char random password.
- To retrieve auto-generated credentials after install:

```powershell
kubectl get secret <release-name>-postgres-secret -o jsonpath='{.data.password}' | base64 -d
kubectl get secret <release-name>-grafana-secret -o jsonpath='{.data.admin-password}' | base64 -d
```

---

## Local Verification & Tests

- Run local quick checks to validate the chart and pipeline scripts:

```powershell
bash tests/helm-validate.sh
bash verify-pipeline-fixes.sh
```

- Integration workflow (in CI) performs:
  - Unit tests with a local PostgreSQL service
  - Docker image build and Trivy scan
  - k3d cluster creation and Helm install into `wiki-test` namespace
  - FastAPI endpoint checks and Grafana dashboard checks via port-forwarding

---

## Files & Workflows to Watch

- Helm chart: `wiki-chart/` (templates, values.yaml, helpers)
- FastAPI service: `wiki-service/` (Dockerfile, `database.py`, `main.py`)
- CI workflows: `.github/workflows/` (`image-scan.yml`, `helm-lint.yml`, `python-quality.yml`, `integration-tests.yml`)

---

## Troubleshooting Highlights

- If Helm installs fail due to namespace mismatches, ensure `helm install --namespace <ns>` is used and templates do not hardcode `metadata.namespace`.
- If k3d cluster creation fails in CI, verify the `rancher/k3s` image tag in `.github/workflows/integration-tests.yml` (we now use `rancher/k3s:v1.31.13-k3s1`).

---

## Appendix: Useful Commands

```powershell
# Run unit+integration tests locally (requires Docker)
bash .github/workflows/scripts/run-local-integration.sh || true

# Validate Helm templates locally
bash tests/helm-validate.sh

# Verify pipeline checks
bash verify-pipeline-fixes.sh
```

---

For more details, inspect the individual workflow and chart files under `.github/workflows/` and `wiki-chart/`.
