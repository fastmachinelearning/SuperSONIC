{{- /* templates/_helpers.tpl */ -}}

{{/*
Get instance name (equal to release name unless overridden)
*/}}
{{- define "supersonic.name" -}}
{{- if .Values.nameOverride }}
  {{- printf "%s" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else }}
  {{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- end -}}

{{/*
Get Triton server name
*/}}
{{- define "supersonic.tritonName" -}}
{{- printf "%s-triton" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Get Envoy proxy name
*/}}
{{- define "supersonic.envoyName" -}}
{{- printf "%s-envoy" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Get gRPC endpoint for client connections
*/}}
{{- define "supersonic.grpcEndpoint" -}}
{{- if .Values.ingress.enabled -}}
{{ .Values.ingress.hostName }}:443
{{- end }}
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
{{- end -}}