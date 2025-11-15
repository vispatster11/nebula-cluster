# Credential Auto-Generation Implementation Summary

## Changes Made

### 1. **values.yaml** - Default Credentials to Empty Strings
- Modified `postgresql.auth.password` from `"postgres"` to `""` (empty string)
- Modified `grafana.adminPassword` from `"admin"` to `""` (empty string)
- Both passwords are now auto-generated at deploy time if not explicitly provided

**Example:**
```yaml
postgresql:
  auth:
    username: postgres
    password: ""  # Auto-generate if empty
    database: wiki

grafana:
  adminPassword: ""  # Auto-generate if empty
  adminUser: admin
```

### 2. **_helpers.tpl** - New Credential Generation Helper
Added `wiki-chart.getOrGeneratePassword` helper function that:
- Returns the provided password if explicitly set in values.yaml
- Attempts to lookup an existing Secret with the same name (for stable upgrades)
- Generates a random 32-character alphanumeric string if no Secret exists

**Key Features:**
- **Deterministic**: Reuses existing credentials across `helm upgrade` operations
- **Secure**: Generates cryptographically random passwords
- **Flexible**: Allows explicit password overrides via CLI flags or values files

### 3. **postgres-secret.yaml** - Auto-Generate Postgres Password
Updated to use the helper function:
```yaml
stringData:
  password: {{ include "wiki-chart.getOrGeneratePassword" (dict "value" .Values.postgresql.auth.password "key" "password" "name" (printf "%s-postgres-secret" (include "wiki-chart.fullname" .)) "namespace" .Values.namespace "context" .) }}
```

### 4. **grafana-secret.yaml** - Auto-Generate Grafana Admin Password
Updated to use the helper function:
```yaml
stringData:
  admin-password: {{ include "wiki-chart.getOrGeneratePassword" (dict "value" .Values.grafana.adminPassword "key" "admin-password" "name" (printf "%s-grafana-secret" (include "wiki-chart.fullname" .)) "namespace" .Values.namespace "context" .) }}
```

### 5. **NOTES.txt** - Updated Post-Install Instructions
Added comprehensive section on credentials management including:
- How to retrieve auto-generated credentials
- How to set custom credentials
- Security best practices
- Updated Grafana access note (now shows "auto-generated password" instead of hardcoded "admin")

## Benefits

✅ **Security**: No secrets committed to git  
✅ **Simplicity**: `helm install` works without manual credential setup  
✅ **Stability**: Credentials persist across `helm upgrade` operations  
✅ **Flexibility**: Users can override with custom credentials  
✅ **Auditability**: All credential operations logged in Kubernetes audit logs  

## Usage Examples

### Basic Installation (Auto-Generate)
```bash
helm install wiki ./wiki-chart
# Credentials auto-generated and stored in Secrets
```

### Custom Credentials
```bash
helm install wiki ./wiki-chart \
  --set postgresql.auth.password=MyP@ssw0rd \
  --set grafana.adminPassword=GrafanaP@ss123
```

### Retrieve Auto-Generated Credentials
```bash
kubectl get secret wiki-postgres-secret -o jsonpath='{.data.password}' | base64 -d
kubectl get secret wiki-grafana-secret -o jsonpath='{.data.admin-password}' | base64 -d
```

### Stable Upgrades (Credentials Preserved)
```bash
helm upgrade wiki ./wiki-chart
# Existing credentials retrieved from Secret, no regeneration
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│  helm install wiki ./wiki-chart                 │
│  (No password values in CLI)                    │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
         ┌─────────────────────┐
         │  postgres-secret    │
         │  grafana-secret     │
         │  (Helm Templates)   │
         └──────────┬──────────┘
                    │
                    ▼
    ┌───────────────────────────────┐
    │ getOrGeneratePassword Helper  │
    ├───────────────────────────────┤
    │ 1. Check if value provided    │
    │    ├─ YES → Use provided val  │
    │    └─ NO → Continue           │
    │ 2. Lookup existing Secret     │
    │    ├─ FOUND → Reuse existing  │
    │    └─ NOT FOUND → Continue    │
    │ 3. Generate random 32-char    │
    └───────────────────────────────┘
                    │
                    ▼
         ┌─────────────────────┐
         │  Kubernetes Secrets │
         │  (Stored encrypted) │
         └─────────────────────┘
```

## Next Steps

The credential auto-generation is now complete. The next priority task is:
- **CI Image Scanning (#12)**: Add GitHub Actions to scan Docker images with Trivy before pushing to registry
- **Helm lint CI (#13)**: Add validation pipeline for Helm chart structure and rendering

All remaining SRE tasks (alerting, backups, scaling, TLS, logging, runtime protection) are queued and ready for implementation.
