{{/*
Scaling and admission metrics.

Default scaling metric: replicas needed by the current in-flight work,

  R_needed = L_envoy / max(L_service / R_healthy, 1)

  L_envoy   - requests in flight between Envoy and the inference servers (rate of the upstream
              request-time counter, ms -> /1e3)
  L_service - requests being executed (rate of server-side request minus queue
              duration, us -> /1e6)
  R_healthy - inference server endpoints Envoy routes to

clamp_min is PromQL for max; the floors keep the division finite and let an
idle fleet scale down. With no inference server series the query is empty, which both
consumers read as no load.

KEDA uses "supersonic.defaultMetric" (metricType AverageValue, desired =
ceil(R_needed / serverLoadThreshold)); the Envoy Lua filter uses
"supersonic.admissionMetric" (per healthy replica) against
"supersonic.admissionThreshold". A custom .Values.serverLoadMetric is
returned verbatim by both.
*/}}

{{/*
Range-vector window for rate() in the default metric.
Keep it at >= 4x the Prometheus scrape interval.
*/}}
{{- define "supersonic.rateInterval" -}}
{{- default "30s" .Values.serverLoadRateInterval -}}
{{- end -}}

{{/*
Healthy inference server endpoints as seen by Envoy.
*/}}
{{- define "supersonic.healthyReplicasExpr" -}}
max(envoy_cluster_membership_healthy{release="{{ include "supersonic.name" . }}", envoy_cluster_name="inference_server_grpc_service"})
{{- end -}}

{{/*
Get default scaling metric (extensive form: replicas needed)
*/}}
{{- define "supersonic.defaultMetric" -}}
{{- if not ( eq .Values.serverLoadMetric "" ) }}
  {{- printf "%s" .Values.serverLoadMetric -}}
{{- else }}
{{- $w := include "supersonic.rateInterval" . }}
sum(rate(envoy_cluster_upstream_rq_time_sum{release="{{ include "supersonic.name" . }}", envoy_cluster_name="inference_server_grpc_service"}[{{ $w }}])) / 1e3
* scalar(clamp_min({{ include "supersonic.healthyReplicasExpr" . }}, 1))
/ clamp_min(
    clamp_min(
      (
        sum(rate(nv_inference_request_duration_us{release="{{ include "supersonic.name" . }}"}[{{ $w }}]))
        -
        sum(rate(nv_inference_queue_duration_us{release="{{ include "supersonic.name" . }}"}[{{ $w }}]))
      ) / 1e6,
      scalar({{ include "supersonic.healthyReplicasExpr" . }})
    ),
    1
  )
{{- end }}
{{- end }}

{{/*
Get admission metric (intensive form: load per healthy replica)
*/}}
{{- define "supersonic.admissionMetric" -}}
{{- if not ( eq .Values.serverLoadMetric "" ) }}
  {{- printf "%s" .Values.serverLoadMetric -}}
{{- else }}
(
{{- include "supersonic.defaultMetric" . }}
)
/ scalar(clamp_min({{ include "supersonic.healthyReplicasExpr" . }}, 1))
{{- end }}
{{- end }}

{{/*
Get scaling threshold (defaults to 1.5 if not set)
*/}}
{{- define "supersonic.defaultThreshold" -}}
{{- default 1.5 .Values.serverLoadThreshold -}}
{{- end -}}

{{/*
Get admission threshold for the Envoy rate limiter (defaults to 3 if not set)
*/}}
{{- define "supersonic.admissionThreshold" -}}
{{- default 3 .Values.serverAdmissionThreshold -}}
{{- end -}}
