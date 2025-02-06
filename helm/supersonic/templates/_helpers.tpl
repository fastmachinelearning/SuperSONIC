{{- /* templates/_helpers.tpl */ -}}

{{/*
Get release name (or override)
*/}}
{{- define "supersonic.name" -}}
{{- if .Values.nameOverride }}
  {{- printf "%s" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else }}
  {{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- end -}}

{{/*
Get Triton name
*/}}
{{- define "supersonic.tritonName" -}}
{{- printf "%s-triton" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Get Envoy name
*/}}
{{- define "supersonic.envoyName" -}}
{{- printf "%s-envoy" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "supersonic.prometheusName" -}}
{{- printf "%s-prometheus" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "supersonic.grafanaName" -}}
{{- printf "%s-grafana" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

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

{{/*
Get gRPC endpoint
*/}}
{{- define "supersonic.grpcEndpoint" -}}
{{- if .Values.ingress.enabled -}}
{{ .Values.ingress.hostName }}:443
{{- end }}
{{- end }}

{{/*
Check if Grafana service exists in the namespace
*/}}
{{- define "supersonic.grafanaExists" -}}
{{- $exists := false -}}
{{- if (lookup "v1" "Service" .Release.Namespace "") }}
  {{- range (lookup "v1" "Service" .Release.Namespace "").items }}
    {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "supersonic") (eq (index .metadata.labels "app.kubernetes.io/component") "grafana") }}
      {{- $exists = true -}}
      {{- break }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $exists -}}
{{- end }}

{{/*
Print warning message about existing Grafana
*/}}
{{- define "supersonic.grafanaExistsWarning" -}}
{{- if and .Values.grafana.enabled (include "supersonic.grafanaExists" .) -}}
{{- printf "\nWARNING: Found existing Grafana instance with service name '%s' in namespace '%s'.\nSkipping Grafana deployment and connecting to the existing instance.\n" (include "supersonic.existingGrafanaName" .) .Release.Namespace | fail -}}
{{- end -}}
{{- end -}}

{{/*
Get existing Grafana service name
*/}}
{{- define "supersonic.existingGrafanaName" -}}
{{- range (lookup "v1" "Service" .Release.Namespace "").items }}
  {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "supersonic") (eq (index .metadata.labels "app.kubernetes.io/component") "grafana") }}
    {{- .metadata.name -}}
    {{- break }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Check if Prometheus service exists in the namespace
*/}}
{{- define "supersonic.prometheusExists" -}}
{{- $exists := false -}}
{{- if (lookup "v1" "Service" .Release.Namespace "") }}
  {{- range (lookup "v1" "Service" .Release.Namespace "").items }}
    {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "supersonic") (eq (index .metadata.labels "app.kubernetes.io/component") "prometheus") }}
      {{- $exists = true -}}
      {{- break }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $exists -}}
{{- end }}

{{/*
Print warning message about existing Prometheus
*/}}
{{- define "supersonic.prometheusExistsWarning" -}}
{{- if and (not .Values.prometheus.external) (include "supersonic.prometheusExists" .) -}}
{{- printf "\nWARNING: Found existing Prometheus instance with service name '%s' in namespace '%s'.\nSkipping Prometheus deployment and connecting to the existing instance.\n" (include "supersonic.existingPrometheusName" .) .Release.Namespace | fail -}}
{{- end -}}
{{- end -}}

{{/*
Get existing Prometheus service name
*/}}
{{- define "supersonic.existingPrometheusName" -}}
{{- range (lookup "v1" "Service" .Release.Namespace "").items }}
  {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "supersonic") (eq (index .metadata.labels "app.kubernetes.io/component") "prometheus") }}
    {{- .metadata.name -}}
    {{- break }}
  {{- end }}
{{- end }}
{{- end }}

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