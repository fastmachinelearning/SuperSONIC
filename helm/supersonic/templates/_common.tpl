{{/*
Common helper functions for SuperSONIC services
*/}}

{{/*
Get service scheme - takes service type and values as parameters
*/}}
{{- define "supersonic.common.getServiceScheme" -}}
{{- $serviceType := .serviceType -}}
{{- $values := .values -}}
{{- if eq $serviceType "prometheus" -}}
    {{- if $values.prometheus.external.enabled -}}
        {{- $values.prometheus.external.scheme -}}
    {{- else if $values.prometheus.enabled -}}
        {{- if and $values.prometheus.server.ingress.enabled $values.prometheus.server.ingress.tls -}}
            {{- printf "https" -}}
        {{- else -}}
            {{- printf "http" -}}
        {{- end -}}
    {{- else -}}
        {{- printf "https" -}}
    {{- end -}}
{{- else if eq $serviceType "grafana" -}}
    {{- if $values.grafana.enabled -}}
        {{- if $values.grafana.ingress.enabled -}}
            {{- if $values.grafana.ingress.tls -}}
                {{- printf "https" -}}
            {{- else -}}
                {{- printf "http" -}}
            {{- end -}}
        {{- else -}}
            {{- printf "http" -}}
        {{- end -}}
    {{- else -}}
        {{- printf "https" -}}
    {{- end -}}
{{- else -}}
    {{- printf "https" -}}
{{- end -}}
{{- end -}}

{{/*
Check if service exists - takes service name as parameter
*/}}
{{- define "supersonic.common.serviceExists" -}}
{{- $serviceName := .serviceName -}}
{{- $exists := "" -}}
{{- if (lookup "apps/v1" "Deployment" .root.Release.Namespace "") -}}
  {{- range (lookup "apps/v1" "Deployment" .root.Release.Namespace "").items -}}
    {{- if and .metadata .metadata.labels (eq (index .metadata.labels "app.kubernetes.io/name") $serviceName) -}}
      {{- $exists = "true" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $exists -}}
{{- end -}}

{{/*
Get service details - takes service type and root context as parameters
*/}}
{{- define "supersonic.common.getServiceDetails" -}}
{{- $serviceType := .serviceType -}}
{{- $root := .root -}}
{{- $defaultPort := .defaultPort | default "80" -}}
{{- $details := dict "scheme" "http" "port" $defaultPort -}}
{{- $found := false -}}

{{- /* Try to get details from ingress first */ -}}
{{- if (lookup "networking.k8s.io/v1" "Ingress" $root.Release.Namespace "") -}}
  {{- range (lookup "networking.k8s.io/v1" "Ingress" $root.Release.Namespace "").items -}}
    {{- if and .metadata .metadata.labels (eq (index .metadata.labels "app.kubernetes.io/name") $serviceType) -}}
      {{- if .spec.rules -}}
        {{- $details = merge $details (dict "host" (index .spec.rules 0).host) -}}
        {{- if .spec.tls -}}
          {{- $details = merge $details (dict "scheme" "https" "port" "443") -}}
        {{- else -}}
          {{- $details = merge $details (dict "port" "80") -}}
        {{- end -}}
        {{- $found = true -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /* Fall back to service if ingress not found */ -}}
{{- if (not $found) -}}
  {{- if (lookup "v1" "Service" $root.Release.Namespace "") -}}
    {{- range (lookup "v1" "Service" $root.Release.Namespace "").items -}}
      {{- if and .metadata .metadata.labels (eq (index .metadata.labels "app.kubernetes.io/name") $serviceType) -}}
        {{- $details = merge $details (dict "host" (printf "%s.%s.svc.cluster.local" .metadata.name $root.Release.Namespace)) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- $details | toJson -}}
{{- end -}}

{{/*
Validate service address consistency
*/}}
{{- define "supersonic.common.validateAddressConsistency" -}}
{{- $serviceType := .serviceType -}}
{{- $values := .values -}}
{{- $root := .root -}}

{{- if eq $serviceType "prometheus" -}}
  {{- if and $values.prometheus.enabled $values.prometheus.server.ingress.enabled -}}
    {{- /* Extract and validate ingress host */ -}}
    {{- if not $values.prometheus.server.ingress.hosts -}}
      {{- fail "Parameter missing: prometheus.server.ingress.hosts" -}}
    {{- end -}}
    {{- $ingressHost := include "supersonic.common.trimUrlScheme" (first $values.prometheus.server.ingress.hosts) -}}

    {{- /* Validate TLS host if TLS is enabled */ -}}
    {{- if $values.prometheus.server.ingress.tls -}}
      {{- if not (first $values.prometheus.server.ingress.tls).hosts -}}
        {{- fail "Parameter missing: prometheus.server.ingress.tls[0].hosts" -}}
      {{- end -}}
      {{- $tlsHost := include "supersonic.common.trimUrlScheme" (first (first $values.prometheus.server.ingress.tls).hosts) -}}
      {{- if ne $ingressHost $tlsHost -}}
        {{- fail (printf "Mismatched configuration. For internal consistency of SuperSONIC components, please set the following parameter:\nprometheus.server.ingress.tls[0].hosts[0]: %s" $ingressHost) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- else if eq $serviceType "grafana" -}}
  {{- if and $values.grafana.enabled $values.grafana.ingress.enabled -}}
    {{- /* Extract and validate ingress host */ -}}
    {{- if not $values.grafana.ingress.hosts -}}
      {{- fail "Parameter missing: grafana.ingress.hosts" -}}
    {{- end -}}
    {{- $ingressHost := include "supersonic.common.trimUrlScheme" (first $values.grafana.ingress.hosts) -}}

    {{- /* Validate TLS host if TLS is enabled */ -}}
    {{- if $values.grafana.ingress.tls -}}
      {{- if not (first $values.grafana.ingress.tls).hosts -}}
        {{- fail "Parameter missing: grafana.ingress.tls[0].hosts" -}}
      {{- end -}}
      {{- $tlsHost := include "supersonic.common.trimUrlScheme" (first (first $values.grafana.ingress.tls).hosts) -}}
      {{- if ne $ingressHost $tlsHost -}}
        {{- fail (printf "Mismatched configuration. For internal consistency of SuperSONIC components, please set the following parameter:\ngrafana.ingress.tls[0].hosts[0]: %s" $ingressHost) -}}
      {{- end -}}
    {{- end -}}

    {{- /* Validate root_url if specified */ -}}
    {{- if (index $values.grafana "grafana.ini").server.root_url -}}
      {{- $rootUrl := include "supersonic.common.trimUrlScheme" (index $values.grafana "grafana.ini").server.root_url -}}
      {{- $expectedRootUrl := printf "https://%s" $ingressHost -}}
      {{- if ne $rootUrl $ingressHost -}}
        {{- fail (printf "Mismatched configuration. For internal consistency of SuperSONIC components, please set the following parameter:\ngrafana.grafana.ini.server.root_url: %s" $expectedRootUrl) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get service name with prefix
*/}}
{{- define "supersonic.common.getServiceName" -}}
{{- $serviceName := .serviceName -}}
{{- printf "%s-%s" (include "supersonic.name" .root) $serviceName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Get service display URL (without standard ports)
*/}}
{{- define "supersonic.common.getServiceDisplayUrl" -}}
{{- $scheme := .scheme -}}
{{- $host := .host -}}
{{- printf "%s://%s" $scheme $host -}}
{{- end -}}

{{/*
Validate no existing service instance when enabling a new one
*/}}
{{- define "supersonic.common.validateNoExistingService" -}}
{{- $serviceType := .serviceType -}}
{{- $values := .values -}}
{{- $root := .root -}}
{{- if and (eq $serviceType "prometheus") (not $values.prometheus.external.enabled) -}}
  {{- if include "supersonic.common.serviceExists" (dict "serviceName" $serviceType "root" $root) -}}
    {{- $details := fromJson (include "supersonic.common.getServiceDetails" (dict "serviceType" $serviceType "root" $root)) -}}
    {{- $url := include "supersonic.common.getServiceDisplayUrl" (dict "scheme" $details.scheme "host" $details.host) -}}
    {{- fail (printf "Error: Found existing %s instance in the namespace:\n- Namespace: %s\n- URL: %s\n\nTo proceed, either:\n1. Set %s.enabled=false in values.yaml to use existing instance, OR\n2. Uninstall the existing instance" $serviceType $root.Release.Namespace $url $serviceType) -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get full service URL
*/}}
{{- define "supersonic.common.getServiceUrl" -}}
{{- $scheme := .scheme -}}
{{- $host := .host -}}
{{- $port := .port -}}
{{- printf "%s://%s:%s" $scheme $host $port -}}
{{- end -}}

{{/*
Get existing service details by type
*/}}
{{- define "supersonic.common.getExistingServiceDetails" -}}
{{- $serviceType := .serviceType -}}
{{- $root := .root -}}
{{- $defaultPort := "" -}}
{{- if eq $serviceType "prometheus" -}}
    {{- $defaultPort = "9090" -}}
{{- else if eq $serviceType "grafana" -}}
    {{- $defaultPort = "80" -}}
{{- end -}}
{{- include "supersonic.common.getServiceDetails" (dict "serviceType" $serviceType "root" $root "defaultPort" $defaultPort) -}}
{{- end -}}

{{/*
Get existing service scheme
*/}}
{{- define "supersonic.common.getExistingServiceScheme" -}}
{{- $details := fromJson (include "supersonic.common.getExistingServiceDetails" .) -}}
{{- $details.scheme -}}
{{- end -}}

{{/*
Get existing service host
*/}}
{{- define "supersonic.common.getExistingServiceHost" -}}
{{- $details := fromJson (include "supersonic.common.getExistingServiceDetails" .) -}}
{{- $details.host -}}
{{- end -}}

{{/*
Get existing service port
*/}}
{{- define "supersonic.common.getExistingServicePort" -}}
{{- $details := fromJson (include "supersonic.common.getExistingServiceDetails" .) -}}
{{- $details.port -}}
{{- end -}}

{{/*
Get existing service URL
*/}}
{{- define "supersonic.common.getExistingServiceUrl" -}}
{{- $serviceType := .serviceType -}}
{{- $values := .values -}}
{{- if eq $serviceType "prometheus" -}}
    {{- include "supersonic.common.trimUrlScheme" $values.prometheus.existingUrl -}}
{{- else if eq $serviceType "grafana" -}}
    {{- include "supersonic.common.trimUrlScheme" $values.grafana.existingUrl -}}
{{- end -}}
{{- end -}}

{{/*
Trim URL scheme and trailing slashes from a URL
*/}}
{{- define "supersonic.common.trimUrlScheme" -}}
{{- $url := . -}}
{{- trimSuffix "://" (trimPrefix "https://" (trimPrefix "http://" $url)) -}}
{{- end -}} 