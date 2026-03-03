{{/*
Chart name truncated to 63 chars.
*/}}
{{- define "streamingapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fullname: release-chart truncated to 63 chars.
*/}}
{{- define "streamingapp.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "streamingapp.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: streamingapp
{{- end }}

{{/*
Selector labels for a specific component
Usage: {{ include "streamingapp.selectorLabels" (dict "component" "auth" "Release" .Release) }}
*/}}
{{- define "streamingapp.selectorLabels" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
