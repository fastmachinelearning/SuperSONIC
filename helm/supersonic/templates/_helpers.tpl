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
https://{{ .Values.prometheus.ingress.hostName }}
{{- else if .Values.prometheus.url -}}
{{ .Values.prometheus.scheme }}://{{ .Values.prometheus.url }}
{{- end }}
{{- end }}