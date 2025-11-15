# Helm Chart Testing

This directory contains tests for the wiki-chart Kubernetes deployment.

## Tests

### 1. Helm Chart Validation (`helm-validate.sh`)
Static validation of the Helm chart without requiring a Kubernetes cluster.

**What it does:**
- Runs `helm lint` to check for chart syntax and best practice issues
- Renders templates with `helm template` to validate YAML structure
- Checks for presence of all required resources (Deployments, Services, Secrets, Ingress, NetworkPolicy, PDB, Test Job)
- Validates security contexts (non-root, dropped capabilities, allowPrivilegeEscalation: false)

**Requirements:**
- `helm` CLI installed

**Run:**
```bash
bash tests/helm-validate.sh
```

**Expected output:**
```
✓ Helm lint passed
✓ Helm templates rendered successfully
✓ Service fastapi found
✓ Deployment fastapi found
... (more resources)
✓ All Helm chart validation tests passed
```

---

### 2. Helm Chart Integration Test (`helm-integrate.sh`)
Deploys the Helm chart to a live Kubernetes cluster and runs the embedded test Job.

**What it does:**
- Checks kubectl/helm availability and cluster connectivity
- Creates an isolated test namespace
- Installs the Helm release into the test namespace
- Waits for the test Job (defined in `test-job.yaml`) to complete
- Collects and displays Job logs
- Cleans up with instructions to delete the namespace

**Requirements:**
- `kubectl` and `helm` CLI installed
- A running Kubernetes cluster (e.g., minikube, kind, EKS, GKE, AKS)
- The FastAPI image built and available (or pre-pulled into the cluster)

**Run:**
```bash
bash tests/helm-integrate.sh
```

**Expected output:**
```
✓ Kubernetes cluster is accessible
✓ Namespace wiki-test ready
✓ Helm chart installed successfully
✓ Test Job completed
Test Job output:
  === Wiki Chart Integration Tests ===
  ✓ FastAPI service is ready
  ✓ Root endpoint works
  ✓ Create user works
  ✓ Get user works
  ✓ Create post works
  ✓ Get post works
  ✓ Metrics endpoint works
  === All tests passed ===
✓ Integration test passed
```

---

## Test Job (`wiki-chart/templates/test-job.yaml`)

A Kubernetes Job that runs inside the cluster after the chart is deployed. It:
- Uses the `curlimages/curl:8.1.0` image for minimal footprint
- Waits for the FastAPI service to be ready (with retries)
- Tests the API endpoints:
  - `GET /` (root)
  - `POST /users` (create user)
  - `GET /user/{id}` (get user)
  - `POST /posts` (create post)
  - `GET /posts/{id}` (get post)
  - `GET /metrics` (Prometheus metrics)
- Uses non-root security context with dropped capabilities
- Fails the job if any test fails (backoffLimit: 0)

---

## Full Test Workflow

```bash
# 1. Validate chart syntax and rendering (no cluster needed)
bash tests/helm-validate.sh

# 2. Deploy to cluster and run integration tests
bash tests/helm-integrate.sh

# 3. (Optional) Clean up test namespace
kubectl delete namespace wiki-test
```

---

## CI/CD Integration

These tests are designed to be run in GitHub Actions or other CI/CD pipelines:

```yaml
# Example GitHub Actions job
- name: Helm Lint
  run: bash tests/helm-validate.sh

- name: Helm Integration Tests
  run: bash tests/helm-integrate.sh
```

See `.github/workflows/helm-test.yml` (if created) for a full CI pipeline example.
