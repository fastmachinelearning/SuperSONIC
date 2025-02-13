{{- /* templates/_helpers.tpl */ -}}

{{/*
Get release name (or override)
*/}}
{{- define "supersonic.name" -}}
{{- if .Values.nameOverride }}
  {{- printf "%s" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else }}
  {{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- end -}}

{{/*
Get Triton name
*/}}
{{- define "supersonic.tritonName" -}}
{{- printf "%s-triton" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Get Envoy name
*/}}
{{- define "supersonic.envoyName" -}}
{{- printf "%s-envoy" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Get gRPC endpoint
*/}}
{{- define "supersonic.grpcEndpoint" -}}
{{- if .Values.ingress.enabled -}}
{{ .Values.ingress.hostName }}:443
{{- end }}
{{- end }}