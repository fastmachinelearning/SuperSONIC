{{/*
Get Prometheus name
*/}}
{{- define "supersonic.prometheusName" -}}
{{- printf "%s-prometheus" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Check if Prometheus exists in the namespace (from any release)
*/}}
{{- define "supersonic.prometheusExists" -}}
{{- $root := . -}}
{{- $exists := false -}}
{{- if (lookup "v1" "Service" .Release.Namespace "") -}}
  {{- range (lookup "v1" "Service" .Release.Namespace "").items -}}
    {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "supersonic") 
               (eq (index .metadata.labels "app.kubernetes.io/component") "prometheus")
               (ne (index .metadata.labels "app.kubernetes.io/instance") (include "supersonic.name" $root))}}
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
             (eq (index .metadata.labels "app.kubernetes.io/component") "prometheus")
             (ne (index .metadata.labels "app.kubernetes.io/instance") (include "supersonic.name" $root))}}
    {{- .metadata.name -}}
    {{- break }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Get Prometheus URL (handles external, ingress, existing, and new instances)
*/}}
{{- define "supersonic.prometheusUrl" -}}
{{- if (not .Values.prometheus.external) -}}
{{- if .Values.prometheus.ingress.enabled -}}
https://{{ .Values.prometheus.ingress.hostName }}
{{- else -}}
http://{{ include "supersonic.prometheusName" . }}.{{ .Release.Namespace }}.svc.cluster.local:9090
{{- end -}}
{{- else if .Values.prometheus.url -}}
{{ .Values.prometheus.scheme }}://{{ .Values.prometheus.url }}
{{- end }}
{{- end }}

{{/*
Validate RBAC permissions for Prometheus
*/}}
{{- define "supersonic.validateRBACPermissions" -}}
{{- if and (not .Values.prometheus.external) (not (include "supersonic.prometheusExists" .)) -}}
  {{- $canReadRoles := false -}}
  {{- if (lookup "rbac.authorization.k8s.io/v1" "Role" .Release.Namespace "") -}}
    {{- $canReadRoles = true -}}
  {{- end -}}
  {{- if not $canReadRoles -}}
    {{- fail "\nError: Failed to install Prometheus due to lack of permissions to get 'roles' in API group 'rbac.authorization.k8s.io'.\nEither:\n1. Set prometheus.external=true in values.yaml and provide an external Prometheus URL, or\n2. Use an existing Prometheus instance in the namespace, or\n3. Request necessary RBAC permissions from your cluster administrator." -}}
  {{- end -}}
{{- end -}}
{{- end -}}