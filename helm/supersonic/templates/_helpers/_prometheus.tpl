{{/*
Get Prometheus name
*/}}
{{- define "supersonic.prometheusName" -}}
{{- include "supersonic.common.getServiceName" (dict "serviceName" "prometheus" "root" .) -}}
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
    {{- include "supersonic.common.trimUrlScheme" .Values.prometheus.external.url -}}
{{- else if .Values.prometheus.enabled -}}
    {{- if and .Values.prometheus.server.ingress.enabled .Values.prometheus.server.ingress.hosts -}}
        {{- include "supersonic.common.trimUrlScheme" (first .Values.prometheus.server.ingress.hosts) -}}
    {{- else -}}
        {{- printf "%s-prometheus-server.%s.svc.cluster.local" (include "supersonic.name" .) .Release.Namespace -}}
    {{- end -}}
{{- else -}}
    {{- include "supersonic.common.getExistingServiceHost" (dict "serviceType" "prometheus" "root" .) -}}
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
    {{- include "supersonic.common.getExistingServicePort" (dict "serviceType" "prometheus" "root" .) -}}
{{- end -}}
{{- end -}}

{{/*
Get full Prometheus URL
*/}}
{{- define "supersonic.prometheusUrl" -}}
{{- include "supersonic.common.getServiceUrl" (dict "scheme" (include "supersonic.prometheusScheme" .) "host" (include "supersonic.prometheusHost" .) "port" (include "supersonic.prometheusPort" .)) -}}
{{- end -}}

{{/*
Check if Prometheus exists in the namespace
*/}}
{{- define "supersonic.prometheusExists" -}}
{{- include "supersonic.common.serviceExists" (dict "serviceName" "prometheus" "root" .) -}}
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
      {{- if ne (include "supersonic.common.trimUrlScheme" .url) (include "supersonic.common.trimUrlScheme" $expectedURL) -}}
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
{{- include "supersonic.common.getServiceDisplayUrl" (dict "scheme" (include "supersonic.prometheusScheme" .) "host" (include "supersonic.prometheusHost" .)) -}}
{{- end -}}
