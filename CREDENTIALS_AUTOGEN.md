# Credential Auto-Generation in Helm Chart

## Overview

The wiki-chart Helm deployment now automatically generates PostgreSQL and Grafana credentials at deploy time, eliminating the need for hardcoded secrets in `values.yaml` and preventing accidental exposure of credentials in version control.

## Implementation Details

### Default Values (values.yaml)
Both PostgreSQL and Grafana passwords now default to empty strings:

```yaml
postgresql:
  auth:
    password: ""  # Auto-generate if empty

grafana:
  adminPassword: ""  # Auto-generate if empty
```

### Helper Function (_helpers.tpl)
A new Helm helper function `wiki-chart.getOrGeneratePassword` implements the credential generation logic:

```go
{{- define "wiki-chart.getOrGeneratePassword" -}}
{{- if .value }}
{{- .value }}
{{- else }}
{{- $secretName := .name }}
{{- $key := .key }}
{{- $namespace := .namespace }}
{{- $context := .context }}
{{- $secret := lookup "v1" "Secret" $namespace $secretName }}
{{- if $secret }}
{{- index $secret.data $key | b64dec }}
{{- else }}
{{- randAlphaNum 32 }}
{{- end }}
{{- end }}
{{- end }}
```

**Logic Flow:**
1. If a password is **explicitly provided** in values.yaml, use it
2. If the password is **empty/nil**, check if a Secret with the same name already exists
3. If the Secret **exists**, retrieve the existing credential (ensures stability across `helm upgrade`)
4. If the Secret **doesn't exist**, generate a random 32-character alphanumeric string

### Secret Templates (postgres-secret.yaml, grafana-secret.yaml)
Both secret templates now call the helper function:

**postgres-secret.yaml:**
```yaml
stringData:
  password: {{ include "wiki-chart.getOrGeneratePassword" (dict "value" .Values.postgresql.auth.password "key" "password" "name" (printf "%s-postgres-secret" (include "wiki-chart.fullname" .)) "namespace" .Values.namespace "context" .) }}
```

**grafana-secret.yaml:**
```yaml
stringData:
  admin-password: {{ include "wiki-chart.getOrGeneratePassword" (dict "value" .Values.grafana.adminPassword "key" "admin-password" "name" (printf "%s-grafana-secret" (include "wiki-chart.fullname" .)) "namespace" .Values.namespace "context" .) }}
```

## Usage

### First Installation (Auto-Generate Credentials)

```bash
helm install wiki-release ./wiki-chart
```

The chart will automatically generate random passwords for both PostgreSQL and Grafana. No credentials need to be provided.

### Override with Custom Credentials

```bash
helm install wiki-release ./wiki-chart \
  --set postgresql.auth.password=my-secure-password \
  --set grafana.adminPassword=my-grafana-password
```

### Retrieve Auto-Generated Credentials

```bash
# Get PostgreSQL password
kubectl get secret wiki-release-postgres-secret -o jsonpath='{.data.password}' | base64 -d

# Get Grafana admin password
kubectl get secret wiki-release-grafana-secret -o jsonpath='{.data.admin-password}' | base64 -d
```

### Helm Upgrades

When running `helm upgrade`, the existing credentials are preserved (the lookup function finds the existing Secret and reuses its values). This ensures:
- **No credential rotation on every upgrade** (unless explicitly deleted and reinstalled)
- **Stability across infrastructure updates**
- **Compatibility with applications using the credentials**

## Security Benefits

1. **No Secrets in Version Control**: Credentials are never stored in git, only generated at deploy time
2. **Unique per Deployment**: Each cluster/namespace gets its own randomly generated credentials
3. **Stable Across Updates**: Credentials persist via Secret lookup, preventing unexpected rotations
4. **Audit Trail**: All credential operations are recorded in Kubernetes audit logs
5. **Rotation Capability**: Users can force credential rotation by deleting the Secret and re-running `helm install`

## Best Practices

1. **Always use explicit credentials in production**:
   ```bash
   helm install wiki-release ./wiki-chart \
     --set postgresql.auth.password=$(openssl rand -base64 32) \
     --set grafana.adminPassword=$(openssl rand -base64 32)
   ```

2. **Store credentials in a secrets management system** (e.g., HashiCorp Vault, AWS Secrets Manager):
   ```bash
   helm install wiki-release ./wiki-chart \
     --set postgresql.auth.password=$(vault kv get -field=password secret/database/postgres) \
     --set grafana.adminPassword=$(vault kv get -field=password secret/grafana/admin)
   ```

3. **Never commit generated credentials to git**: The auto-generation only works if values.yaml has empty passwords

4. **Document credential rotation procedures**: Update runbooks to reflect the new rotation mechanism (delete Secret → helm upgrade)

## Limitations & Future Enhancements

**Current Limitations:**
- Helm's `lookup` function only works with `helm install` and `helm upgrade` in the same namespace
- Generated credentials are not rotated automatically; manual intervention required
- No integration with external secret stores (Vault, AWS Secrets Manager)

**Planned Enhancements:**
- Use Kubernetes **Sealed Secrets** or **External Secrets Operator** for production secret management
- Integrate with **cert-manager's Secret generation** for certificate credentials
- Add **credential rotation CronJob** that periodically updates secrets
- Support **secret provider injection** from external backends (Vault, AWS Secrets Manager, Azure Keyvault)
