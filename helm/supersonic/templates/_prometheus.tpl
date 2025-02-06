{{/*
Get Prometheus name
*/}}
{{- define "supersonic.prometheusName" -}}
{{- printf "%s-prometheus" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Check if Prometheus service exists in the namespace (from any release)
*/}}
{{- define "supersonic.prometheusExists" -}}
{{- $root := . -}}
{{- $exists := false -}}
{{- if (lookup "v1" "Service" .Release.Namespace "") -}}
  {{- range (lookup "v1" "Service" .Release.Namespace "").items -}}
    {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "supersonic") 
               (eq (index .metadata.labels "app.kubernetes.io/component") "prometheus") -}}
      {{- $exists = true -}}
      {{- break -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $exists -}}
{{- end -}}

{{/*
Get existing Prometheus service name (from any release)
*/}}
{{- define "supersonic.existingPrometheusName" -}}
{{- $root := . -}}
{{- range (lookup "v1" "Service" .Release.Namespace "").items }}
  {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "supersonic") 
             (eq (index .metadata.labels "app.kubernetes.io/component") "prometheus") }}
    {{- .metadata.name -}}
    {{- break }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Get Prometheus URL (handles external, existing, and new instances)
*/}}
{{- define "supersonic.prometheusUrl" -}}
{{- if .Values.prometheus.external -}}
{{ .Values.prometheus.scheme }}://{{ .Values.prometheus.url }}
{{- else if (include "supersonic.prometheusExists" .) -}}
http://{{ include "supersonic.existingPrometheusName" . }}.{{ .Release.Namespace }}.svc.cluster.local:9090
{{- else -}}
http://{{ include "supersonic.prometheusName" . }}.{{ .Release.Namespace }}.svc.cluster.local:9090
{{- end }}
{{- end }}

{{/*
Validate RBAC permissions for Prometheus
*/}}
{{- define "supersonic.validateRBACPermissions" -}}
{{- if not .Values.prometheus.external -}}
  {{- $canReadRoles := false -}}
  {{- if (lookup "rbac.authorization.k8s.io/v1" "Role" .Release.Namespace "") -}}
    {{- $canReadRoles = true -}}
  {{- end -}}
  {{- if not $canReadRoles -}}
    {{- fail "\nError: Failed to install Prometheus due to lack of permissions to get 'roles' in API group 'rbac.authorization.k8s.io'.\nEither:\n1. Set prometheus.external=true in value.yaml and provide an external Prometheus URL, or\n2. Request necessary RBAC permissions from your cluster administrator." -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Default metric for autoscaling
*/}}
{{- define "supersonic.defaultMetric" -}}
{{- if not ( eq .Values.prometheus.serverLoadMetric "" ) }}
  {{- printf "%s" .Values.prometheus.serverLoadMetric -}}
{{- else }}
sum by (job) (
    rate(nv_inference_queue_duration_us{job=~"{{ include "supersonic.tritonName" . }}"}[15s])
)
  /
sum by (job) (
    (rate(nv_inference_exec_count{job=~"{{ include "supersonic.tritonName" . }}"}[15s]) * 1000) + 0.001
)
{{- end }}
{{- end }} 