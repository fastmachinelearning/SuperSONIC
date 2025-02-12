{{/*
Get Prometheus name
*/}}
{{- define "supersonic.prometheusName" -}}
{{- printf "%s-prometheus" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Get Prometheus scheme
*/}}
{{- define "supersonic.prometheusScheme" -}}
{{- if .Values.prometheus.external.enabled -}}
    {{- .Values.prometheus.external.scheme -}}
{{- else if .Values.prometheus.enabled -}}
    {{- if and .Values.prometheus.server.ingress.enabled .Values.prometheus.server.ingress.tls -}}
        {{- printf "https" -}}
    {{- else -}}
        {{- printf "http" -}}
    {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get Prometheus host
*/}}
{{- define "supersonic.prometheusHost" -}}
{{- if .Values.prometheus.external.enabled -}}
    {{- .Values.prometheus.external.url -}}
{{- else if .Values.prometheus.enabled -}}
    {{- if and .Values.prometheus.server.ingress.enabled .Values.prometheus.server.ingress.hosts -}}
        {{- first .Values.prometheus.server.ingress.hosts -}}
    {{- else -}}
        {{- printf "%s-prometheus-server.%s.svc.cluster.local" (include "supersonic.name" .) .Release.Namespace -}}
    {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get Prometheus port
*/}}
{{- define "supersonic.prometheusPort" -}}
{{- if .Values.prometheus.external.enabled -}}
    {{- .Values.prometheus.external.port -}}
{{- else if .Values.prometheus.enabled -}}
    {{- if and .Values.prometheus.server.ingress.enabled .Values.prometheus.server.ingress.tls -}}
        {{- printf "443" -}}
    {{- else if .Values.prometheus.server.ingress.enabled -}}
        {{- printf "80" -}}
    {{- else -}}
        {{- .Values.prometheus.server.service.servicePort | default "9090" -}}
    {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get full Prometheus URL
*/}}
{{- define "supersonic.prometheusUrl" -}}
{{- printf "%s://%s:%s" (include "supersonic.prometheusScheme" .) (include "supersonic.prometheusHost" .) (include "supersonic.prometheusPort" .) -}}
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