{{/*
Get Grafana name
*/}}
{{- define "supersonic.grafanaName" -}}
{{- printf "%s-grafana" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Get Grafana scheme
*/}}
{{- define "supersonic.grafanaScheme" -}}
{{- include "supersonic.common.getServiceScheme" (dict "serviceType" "grafana" "values" .Values) -}}
{{- end -}}

{{/*
Get Grafana host
*/}}
{{- define "supersonic.grafanaHost" -}}
{{- if .Values.grafana.enabled -}}
    {{- if and .Values.grafana.ingress.enabled .Values.grafana.ingress.hosts -}}
        {{- first .Values.grafana.ingress.hosts -}}
    {{- else -}}
        {{- printf "%s-grafana.%s.svc.cluster.local" .Release.Name .Release.Namespace -}}
    {{- end -}}
{{- else -}}
    {{- include "supersonic.existingGrafanaHost" . -}}
{{- end -}}
{{- end -}}

{{/*
Get Grafana port
*/}}
{{- define "supersonic.grafanaPort" -}}
{{- if .Values.grafana.enabled -}}
    {{- if .Values.grafana.ingress.enabled -}}
        {{- if .Values.grafana.ingress.tls -}}
            {{- printf "443" -}}
        {{- else -}}
            {{- printf "80" -}}
        {{- end -}}
    {{- else -}}
        {{- .Values.grafana.service.port | default "80" -}}
    {{- end -}}
{{- else -}}
    {{- include "supersonic.existingGrafanaPort" . -}}
{{- end -}}
{{- end -}}

{{/*
Get full Grafana URL
*/}}
{{- define "supersonic.grafanaUrl" -}}
{{- printf "%s://%s:%s" (include "supersonic.grafanaScheme" .) (include "supersonic.grafanaHost" .) (include "supersonic.grafanaPort" .) -}}
{{- end -}}

{{/*
Check if Grafana exists in the namespace
*/}}
{{- define "supersonic.grafanaExists" -}}
{{- include "supersonic.common.serviceExists" (dict "serviceName" "grafana" "root" .) -}}
{{- end -}}

{{/*
Get existing Grafana details
*/}}
{{- define "supersonic.getExistingGrafanaDetails" -}}
{{- include "supersonic.common.getServiceDetails" (dict "serviceType" "grafana" "root" . "defaultPort" "80") -}}
{{- end -}}

{{/*
Get existing Grafana scheme
*/}}
{{- define "supersonic.existingGrafanaScheme" -}}
{{- $details := fromJson (include "supersonic.getExistingGrafanaDetails" .) -}}
{{- $details.scheme -}}
{{- end -}}

{{/*
Get existing Grafana host
*/}}
{{- define "supersonic.existingGrafanaHost" -}}
{{- $details := fromJson (include "supersonic.getExistingGrafanaDetails" .) -}}
{{- $details.host -}}
{{- end -}}

{{/*
Get existing Grafana port
*/}}
{{- define "supersonic.existingGrafanaPort" -}}
{{- $details := fromJson (include "supersonic.getExistingGrafanaDetails" .) -}}
{{- $details.port -}}
{{- end -}}

{{/*
Get existing Grafana URL
*/}}
{{- define "supersonic.existingGrafanaUrl" -}}
{{- .Values.grafana.existingUrl -}}
{{- end -}}

{{/*
Validate that there is no existing Grafana instance when enabling a new one
*/}}
{{- define "supersonic.validateGrafana" -}}
{{- if .Values.grafana.enabled -}}
  {{- if include "supersonic.grafanaExists" . -}}
    {{- $details := fromJson (include "supersonic.getExistingGrafanaDetails" .) -}}
    {{- $url := printf "%s://%s:%s" $details.scheme $details.host $details.port -}}
    {{- fail (printf "Error: Found existing Grafana instance in the namespace:\n- Namespace: %s\n- URL: %s\n\nTo proceed, either:\n1. Set grafana.enabled=false in values.yaml to use the existing Grafana instance, OR\n2. Uninstall the existing Grafana instance" .Release.Namespace $url) -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validate Grafana address consistency
*/}}
{{- define "supersonic.validateGrafanaAddressConsistency" -}}
{{- include "supersonic.common.validateAddressConsistency" (dict "serviceType" "grafana" "values" .Values "root" .) -}}
{{- end -}}

{{/*
Validate Grafana configuration values
*/}}
{{- define "supersonic.validateGrafanaValues" -}}
{{- if .Values.grafana.enabled -}}
  {{- $releaseName := include "supersonic.name" . -}}
  {{- $root := . -}}

  {{- /* Validate default dashboard name */ -}}
  {{- if .Values.grafana.dashboardsConfigMaps -}}
    {{- $configMapName := .Values.grafana.dashboardsConfigMaps.default -}}
    {{- $expectedName := printf "%s-grafana-default-dashboard" $releaseName -}}
    {{- if ne $configMapName $expectedName -}}
      {{- fail (printf "Mismatched configuration. For internal consistency of SuperSONIC components, please set the following parameter:\ngrafana.dashboardsConfigMaps.default: %s" $expectedName) -}}
    {{- end -}}
  {{- end -}}

  {{- /* Validate Prometheus datasource URL */ -}}
  {{- if .Values.grafana.datasources -}}
    {{- range (index .Values.grafana.datasources "datasources.yaml").datasources -}}
      {{- if and (eq .type "prometheus") .url -}}
        {{- if $root.Values.prometheus.external.enabled -}}
          {{- $expectedURL := printf "%s://%s" $root.Values.prometheus.external.scheme $root.Values.prometheus.external.url -}}
          {{- if ne .url $expectedURL -}}
            {{- fail (printf "Mismatched configuration. For internal consistency of SuperSONIC components with external Prometheus, please set the following parameter:\ngrafana:\n  datasources:\n    datasources.yaml:\n      datasources:\n        - name: prometheus\n          type: prometheus\n          access: proxy\n          url: %s" $expectedURL) -}}
          {{- end -}}
        {{- else if $root.Values.prometheus.enabled -}}
          {{- $expectedURL := printf "http://%s-prometheus-server:9090" $releaseName -}}
          {{- if ne .url $expectedURL -}}
            {{- fail (printf "Mismatched configuration. For internal consistency of SuperSONIC components with internal Prometheus, please set the following parameter:\ngrafana:\n  datasources:\n    datasources.yaml:\n      datasources:\n        - name: prometheus\n          type: prometheus\n          access: proxy\n          url: %s" $expectedURL) -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get full Grafana URL for display (without standard ports)
*/}}
{{- define "supersonic.grafanaDisplayUrl" -}}
{{- $scheme := include "supersonic.grafanaScheme" . -}}
{{- $host := include "supersonic.grafanaHost" . -}}
{{- printf "%s://%s" $scheme $host -}}
{{- end -}}