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
{{- if .Values.prometheus.external -}}
  {{- if and .Values.prometheus.url .Values.prometheus.scheme -}}
{{ .Values.prometheus.scheme }}://{{ .Values.prometheus.url }}
  {{- else -}}
http://{{ include "supersonic.prometheusName" . }}.{{ .Release.Namespace }}.svc.cluster.local:9090
  {{- end -}}
{{- else if and .Values.prometheus.ingress.enabled .Values.prometheus.ingress.hostName -}}
https://{{ .Values.prometheus.ingress.hostName }}
{{- else -}}
  {{- $foundIngress := false -}}
  {{- if (lookup "networking.k8s.io/v1" "Ingress" .Release.Namespace "") -}}
    {{- $root := . -}}
    {{- range (lookup "networking.k8s.io/v1" "Ingress" .Release.Namespace "").items -}}
      {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "supersonic") 
                 (eq (index .metadata.labels "app.kubernetes.io/component") "prometheus")
                 (ne (index .metadata.labels "app.kubernetes.io/instance") (include "supersonic.name" $root))}}
        {{- range .spec.rules -}}
          {{- if .host -}}
            {{- $foundIngress = true -}}
https://{{ .host }}
            {{- break -}}
          {{- end -}}
        {{- end -}}
        {{- break -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- if not $foundIngress -}}
    {{- if (eq (include "supersonic.prometheusExists" .) "true") -}}
http://{{ include "supersonic.existingPrometheusName" . }}.{{ .Release.Namespace }}.svc.cluster.local:9090
    {{- else -}}
http://{{ include "supersonic.prometheusName" . }}.{{ .Release.Namespace }}.svc.cluster.local:9090
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

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