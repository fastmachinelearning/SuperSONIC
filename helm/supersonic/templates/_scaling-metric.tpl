{{/*
Get default scaling metric
*/}}
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
Get server load threshold (defaults to 100 if not set)
*/}}
{{- define "supersonic.serverLoadThreshold" -}}
{{- default 100 .Values.prometheus.serverLoadThreshold -}}
{{- end -}} 