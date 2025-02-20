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
{{- if .Values.envoy.enabled -}}
  {{- if .Values.envoy.ingress.enabled -}}
    {{- printf "%s:443" .Values.envoy.ingress.hostName -}}
  {{- else -}}
    {{- $serviceName := include "supersonic.name" . -}}
    {{- $grpcPort := 8001 -}}
    {{- range .Values.envoy.service.ports -}}
      {{- if eq .name "grpc" -}}
        {{- $grpcPort = .port -}}
      {{- end -}}
    {{- end -}}
    {{- printf "%s.%s.svc.cluster.local:%d" $serviceName .Release.Namespace $grpcPort -}}
  {{- end -}}
{{- end -}}
{{- end -}}
