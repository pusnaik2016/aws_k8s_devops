{{/*
Common labels for all resources
*/}}
{{- define "transaction-ingestion.labels" -}}
app.kubernetes.io/name: transaction-ingestion
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/component: ingestion
app.kubernetes.io/part-of: clearing-engine
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
compliance: hipaa-sox-gdpr
{{- end }}

{{/*
Selector labels
*/}}
{{- define "transaction-ingestion.selectorLabels" -}}
app.kubernetes.io/name: transaction-ingestion
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Full image path
*/}}
{{- define "transaction-ingestion.image" -}}
{{- $registry := .Values.global.imageRegistry -}}
{{- $repo := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Values.global.imageTag | default .Chart.AppVersion -}}
{{- if $registry -}}
{{ $registry }}/{{ $repo }}:{{ $tag }}
{{- else -}}
{{ $repo }}:{{ $tag }}
{{- end -}}
{{- end }}
