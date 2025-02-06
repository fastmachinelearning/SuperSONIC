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

{{- define "supersonic.defaultMetric" -}}
{{- if not ( eq .Values.prometheus.serverLoadMetric "" ) }}
  {{- printf "%s" .Values.prometheus.serverLoadMetric -}}
{{- else }}
sum by (release) (
    rate(nv_inference_queue_duration_us{release=~"{{ include "supersonic.name" . }}"}[15s])
)
  /
sum by (release) (
    (rate(nv_inference_exec_count{release=~"{{ include "supersonic.name" . }}"}[15s]) * 1000) + 0.001
)
{{- end }}
{{- end }}

{{/*
Get gRPC endpoint
*/}}
{{- define "supersonic.grpcEndpoint" -}}
{{- if .Values.ingress.enabled -}}
{{ .Values.ingress.hostName }}:443
{{- end }}
{{- end }}