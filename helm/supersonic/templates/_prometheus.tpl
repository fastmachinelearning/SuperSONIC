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

{{/*
Validate Prometheus configuration values
*/}}
{{- define "supersonic.validatePrometheusValues" -}}
{{- $releaseName := include "supersonic.name" . -}}

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
Validate Prometheus address consistency across ingress host and TLS host
*/}}
{{- define "supersonic.validatePrometheusAddressConsistency" -}}
{{- if and .Values.prometheus.enabled .Values.prometheus.server.ingress.enabled -}}
  {{- /* Extract and validate ingress host */ -}}
  {{- if not .Values.prometheus.server.ingress.hosts -}}
    {{- fail "Parameter missing: prometheus.server.ingress.hosts" -}}
  {{- end -}}
  {{- $ingressHost := first .Values.prometheus.server.ingress.hosts -}}

  {{- /* Validate TLS host if TLS is enabled */ -}}
  {{- if .Values.prometheus.server.ingress.tls -}}
    {{- if not (first .Values.prometheus.server.ingress.tls).hosts -}}
      {{- fail "Parameter missing: prometheus.server.ingress.tls[0].hosts" -}}
    {{- end -}}
    {{- $tlsHost := first (first .Values.prometheus.server.ingress.tls).hosts -}}
    {{- if ne $ingressHost $tlsHost -}}
      {{- fail (printf "Mismatched configuration. For internal consistency of SuperSONIC components, please set the following parameter:\nprometheus.server.ingress.tls[0].hosts[0]: %s" $ingressHost) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}