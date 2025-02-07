{{- /* templates/_helpers.tpl */ -}}
{{- define "supersonic.name" -}}
{{- if .Values.nameOverride }}
  {{- printf "%s" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else }}
  {{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- end -}}

{{- define "supersonic.tritonName" -}}
{{- printf "%s-triton" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

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

{{- define "supersonic.grpcEndpoint" -}}
{{- if .Values.ingress.enabled -}}
{{ .Values.ingress.hostName }}:443
{{- end }}
{{- end }}

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

{{/*
Validate that there is no existing Grafana instance when enabling a new one
*/}}
{{- define "supersonic.validateGrafana" -}}
{{- if .Values.grafana.enabled -}}
  {{- if (lookup "v1" "Service" .Release.Namespace "") -}}
    {{- $root := . -}}
    {{- range (lookup "v1" "Service" .Release.Namespace "").items -}}
      {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "grafana") 
                 (eq (index .metadata.labels "app.kubernetes.io/instance") "supersonic")}}
        {{- $releaseName := index .metadata.annotations "meta.helm.sh/release-name" -}}
        {{- $podName := "" -}}
        {{- if (lookup "v1" "Pod" $root.Release.Namespace "") -}}
          {{- range (lookup "v1" "Pod" $root.Release.Namespace "").items -}}
            {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "grafana") 
                       (eq (index .metadata.labels "app.kubernetes.io/instance") $releaseName) }}
              {{- $podName = .metadata.name -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}
        {{- $supersonic_release := "" -}}
        {{- if (lookup "v1" "Service" $root.Release.Namespace "") -}}
          {{- range (lookup "v1" "Service" $root.Release.Namespace "").items -}}
            {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "supersonic") 
                       (eq (index .metadata.labels "app.kubernetes.io/instance") $releaseName) }}
              {{- $supersonic_release = $releaseName -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}
        {{- fail (printf "\n\nError: Found existing Grafana instance in the namespace:\n    • Pod name: %s\n    • Related to SuperSONIC release: %s\nTo proceed, either:\n    1. Set grafana.enabled=false in values.yaml to use the existing Grafana instance, or\n    2. Remove the existing Grafana instance by running:\n        helm upgrade %s fastml/supersonic --reuse-values --set grafana.enabled=false -n %s" $podName (default "standalone Grafana" $supersonic_release) $releaseName $root.Release.Namespace) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}