{{/*
Common labels for all resources
*/}}
{{- define "notification-service.labels" -}}
app.kubernetes.io/name: notification-service
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/component: notification
app.kubernetes.io/part-of: clearing-engine
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
compliance: hipaa-sox-gdpr
{{- end }}

{{/*
Selector labels
*/}}
{{- define "notification-service.selectorLabels" -}}
app.kubernetes.io/name: notification-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Full image path
*/}}
{{- define "notification-service.image" -}}
{{- $registry := .Values.global.imageRegistry -}}
{{- $repo := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Values.global.imageTag | default .Chart.AppVersion -}}
{{- if $registry -}}
{{ $registry }}/{{ $repo }}:{{ $tag }}
{{- else -}}
{{ $repo }}:{{ $tag }}
{{- end -}}
{{- end }}
