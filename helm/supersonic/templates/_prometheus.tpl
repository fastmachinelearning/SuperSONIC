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
{{- include "supersonic.common.getServiceScheme" (dict "serviceType" "prometheus" "values" .Values) -}}
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
{{- else -}}
    {{- include "supersonic.existingPrometheusHost" . -}}
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
{{- else -}}
    {{- include "supersonic.existingPrometheusPort" . -}}
{{- end -}}
{{- end -}}

{{/*
Get full Prometheus URL
*/}}
{{- define "supersonic.prometheusUrl" -}}
{{- printf "%s://%s:%s" (include "supersonic.prometheusScheme" .) (include "supersonic.prometheusHost" .) (include "supersonic.prometheusPort" .) -}}
{{- end -}}

{{/*
Check if Prometheus exists in the namespace
*/}}
{{- define "supersonic.prometheusExists" -}}
{{- include "supersonic.common.serviceExists" (dict "serviceName" "prometheus" "root" .) -}}
{{- end -}}

{{/*
Get existing Prometheus details
*/}}
{{- define "supersonic.getExistingPrometheusDetails" -}}
{{- include "supersonic.common.getServiceDetails" (dict "serviceType" "prometheus" "root" . "defaultPort" "9090") -}}
{{- end -}}

{{/*
Get existing Prometheus scheme
*/}}
{{- define "supersonic.existingPrometheusScheme" -}}
{{- $details := fromJson (include "supersonic.getExistingPrometheusDetails" .) -}}
{{- $details.scheme -}}
{{- end -}}

{{/*
Get existing Prometheus host
*/}}
{{- define "supersonic.existingPrometheusHost" -}}
{{- $details := fromJson (include "supersonic.getExistingPrometheusDetails" .) -}}
{{- $details.host -}}
{{- end -}}

{{/*
Get existing Prometheus port
*/}}
{{- define "supersonic.existingPrometheusPort" -}}
{{- $details := fromJson (include "supersonic.getExistingPrometheusDetails" .) -}}
{{- $details.port -}}
{{- end -}}

{{/*
Get existing Prometheus URL
*/}}
{{- define "supersonic.existingPrometheusUrl" -}}
{{- .Values.prometheus.existingUrl -}}
{{- end -}}

{{/*
Validate that there is no existing Prometheus instance when enabling a new one
*/}}
{{- define "supersonic.validatePrometheus" -}}
{{- if and .Values.prometheus.enabled (not .Values.prometheus.external.enabled) -}}
  {{- if include "supersonic.prometheusExists" . -}}
    {{- $details := fromJson (include "supersonic.getExistingPrometheusDetails" .) -}}
    {{- $url := include "supersonic.prometheusDisplayUrl" . -}}
    {{- fail (printf "Error: Found existing Prometheus instance in the namespace:\n- Namespace: %s\n- URL: %s\n\nTo proceed, either:\n1. Set prometheus.enabled=false in values.yaml to use existing Prometheus instance, OR\n2. Set prometheus.external.enabled=true and provide external Prometheus URL, OR\n3. Uninstall the existing Prometheus instance" .Release.Namespace $url) -}}
  {{- end -}}
{{- end -}}
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

{{/*
Validate Prometheus configuration values
*/}}
{{- define "supersonic.validatePrometheusValues" -}}
{{- $releaseName := include "supersonic.name" . -}}

{{- if .Values.prometheus.enabled -}}
  {{- /* Validate cluster role name */ -}}
  {{- if .Values.prometheus.server.useExistingClusterRoleName -}}
    {{- $expectedRole := printf "%s-prometheus-role" $releaseName -}}
    {{- if ne .Values.prometheus.server.useExistingClusterRoleName $expectedRole -}}
      {{- fail (printf "Mismatched configuration. For internal consistency of SuperSONIC components, please set the following parameter:\nprometheus.server.useExistingClusterRoleName: %s" $expectedRole) -}}
    {{- end -}}
  {{- end -}}

  {{- /* Validate service account name */ -}}
  {{- if .Values.prometheus.serviceAccounts.server.name -}}
    {{- $expectedSA := printf "%s-prometheus-sa" $releaseName -}}
    {{- if ne .Values.prometheus.serviceAccounts.server.name $expectedSA -}}
      {{- fail (printf "Mismatched configuration. For internal consistency of SuperSONIC components, please set the following parameter:\nprometheus.serviceAccounts.server.name: %s" $expectedSA) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /* Validate Prometheus server URL in datasources */ -}}
{{- if .Values.grafana.enabled -}}
  {{- range (index .Values.grafana "datasources.yaml").datasources -}}
    {{- if and (eq .type "prometheus") .url -}}
      {{- $expectedURL := printf "http://%s-prometheus-server:9090" $releaseName -}}
      {{- if ne .url $expectedURL -}}
        {{- fail (printf "Mismatched configuration. For internal consistency of SuperSONIC components, please set the following parameter:\ngrafana.datasources.yaml.datasources[].url: %s" $expectedURL) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validate Prometheus address consistency
*/}}
{{- define "supersonic.validatePrometheusAddressConsistency" -}}
{{- include "supersonic.common.validateAddressConsistency" (dict "serviceType" "prometheus" "values" .Values "root" .) -}}
{{- end -}}

{{/*
Get full Prometheus URL for display (without standard ports)
*/}}
{{- define "supersonic.prometheusDisplayUrl" -}}
{{- $scheme := include "supersonic.prometheusScheme" . -}}
{{- $host := include "supersonic.prometheusHost" . -}}
{{- printf "%s://%s" $scheme $host -}}
{{- end -}}
