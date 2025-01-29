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
    nv_inference_queue_duration_us{job=~"{{ include "supersonic.tritonName" . }}"}
)
  /
sum by (job) (
    (nv_inference_exec_count{job=~"{{ include "supersonic.tritonName" . }}"} * 1000) + 0.001
)
{{- end }}
{{- end }}