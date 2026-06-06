{{- define "ecommerce-app.labels" -}}
app: {{ .Values.nameOverride | default .Chart.Name }}
app.kubernetes.io/name: {{ .Values.nameOverride | default .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "ecommerce-app.selectorLabels" -}}
app: {{ .Values.nameOverride | default .Chart.Name }}
app.kubernetes.io/name: {{ .Values.nameOverride | default .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
