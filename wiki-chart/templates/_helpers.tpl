{{/*
Expand the name of the chart.
*/}}
{{- define "wiki-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "wiki-chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "wiki-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "wiki-chart.labels" -}}
helm.sh/chart: {{ include "wiki-chart.chart" . }}
{{ include "wiki-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "wiki-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wiki-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Generate or retrieve a credential (password/secret).
If the value is provided (non-empty), use it. Otherwise, generate a random 32-char alphanumeric string.
To ensure consistency across helm upgrades, we store generated credentials in a Secret annotation.
Usage: {{ include "wiki-chart.getOrGeneratePassword" (dict "value" .Values.postgresql.auth.password "key" "postgres-password" "name" "postgres-secret" "namespace" .Release.Namespace "context" .) }}
*/}}
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
