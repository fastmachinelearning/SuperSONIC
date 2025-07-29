{{/*
Get Grafana name
*/}}
{{- define "supersonic.grafanaName" -}}
{{- include "supersonic.common.getServiceName" (dict "serviceName" "grafana" "root" .) -}}
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
        {{- include "supersonic.common.trimUrlScheme" (first .Values.grafana.ingress.hosts) -}}
    {{- else -}}
        {{- printf "%s-grafana.%s.svc.cluster.local" .Release.Name .Release.Namespace -}}
    {{- end -}}
{{- else -}}
    {{- include "supersonic.common.getExistingServiceHost" (dict "serviceType" "grafana" "root" .) -}}
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
    {{- include "supersonic.common.getExistingServicePort" (dict "serviceType" "grafana" "root" .) -}}
{{- end -}}
{{- end -}}

{{/*
Get full Grafana URL
*/}}
{{- define "supersonic.grafanaUrl" -}}
{{- include "supersonic.common.getServiceUrl" (dict "scheme" (include "supersonic.grafanaScheme" .) "host" (include "supersonic.grafanaHost" .) "port" (include "supersonic.grafanaPort" .)) -}}
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
          {{- $expectedURL := printf "%s://%s" $root.Values.prometheus.external.scheme (include "supersonic.common.trimUrlScheme" $root.Values.prometheus.external.url) -}}
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
{{- include "supersonic.common.getServiceDisplayUrl" (dict "scheme" (include "supersonic.grafanaScheme" .) "host" (include "supersonic.grafanaHost" .)) -}}
{{- end -}}