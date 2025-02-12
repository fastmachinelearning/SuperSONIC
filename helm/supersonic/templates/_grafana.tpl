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
{{- if .Values.grafana.ingress.enabled -}}
    {{- if .Values.grafana.ingress.tls -}}
        {{- printf "https" -}}
    {{- else -}}
        {{- printf "http" -}}
    {{- end -}}
{{- else -}}
    {{- printf "http" -}}
{{- end -}}
{{- end -}}

{{/*
Get Grafana host
*/}}
{{- define "supersonic.grafanaHost" -}}
{{- if and .Values.grafana.ingress.enabled .Values.grafana.ingress.hosts -}}
    {{- first .Values.grafana.ingress.hosts -}}
{{- else -}}
    {{- printf "%s-grafana.%s.svc.cluster.local" .Release.Name .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Get Grafana port
*/}}
{{- define "supersonic.grafanaPort" -}}
{{- if .Values.grafana.ingress.enabled -}}
    {{- if .Values.grafana.ingress.tls -}}
        {{- printf "443" -}}
    {{- else -}}
        {{- printf "80" -}}
    {{- end -}}
{{- else -}}
    {{- .Values.grafana.service.port | default "80" -}}
{{- end -}}
{{- end -}}

{{/*
Get full Grafana URL
*/}}
{{- define "supersonic.grafanaUrl" -}}
{{- printf "%s://%s:%s" (include "supersonic.grafanaScheme" .) (include "supersonic.grafanaHost" .) (include "supersonic.grafanaPort" .) -}}
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
                 (ne (index .metadata.labels "app.kubernetes.io/instance") (include "supersonic.name" $root))}}
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
        {{- $message := cat "" -}}
Error: Found existing Grafana instance in the namespace:
- Pod name: {{ $podName }}
- Related to SuperSONIC release: {{ default "standalone Grafana" $supersonic_release }}

To proceed, either:
1. Set grafana.enabled=false in values.yaml to use the existing Grafana instance, or
2. Remove the existing Grafana instance by running:
   helm upgrade {{ $releaseName }} fastml/supersonic --reuse-values --set grafana.enabled=false -n {{ $root.Release.Namespace }}
        {{- $message | nindent 0 | fail -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}