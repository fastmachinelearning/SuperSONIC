{{/*
Scaling and admission metrics.

The default scaling metric estimates how many replicas the current in-flight
work needs:

  R_needed = L_envoy / max(L_service / R_healthy, 1)

  L_envoy   - mean requests in flight between Envoy and Triton: rate of
              Envoy's cumulative upstream request-time counter (ms -> /1e3).
  L_service - mean requests being executed across all models and pods: rate
              of Triton's request-duration minus queue-duration counters
              (us -> /1e6).
  R_healthy - Triton endpoints Envoy routes to (max across Envoy pods).

clamp_min(v, s) is PromQL for max(v, s). The floors encode that a healthy
replica can always execute at least one request, and that at zero replicas
the metric reads "requests in flight" instead of dividing by zero.

KEDA consumes "supersonic.defaultMetric" (the form above) with metricType
AverageValue: desired = ceil(R_needed / serverLoadThreshold). The Envoy Lua
filter consumes "supersonic.admissionMetric" (the same per healthy replica)
and rejects RepositoryIndex above "supersonic.admissionThreshold".

If .Values.serverLoadMetric is set, both helpers return it verbatim.
*/}}

{{/*
Range-vector window for rate() in the default metric.
Keep it at >= 4x the Prometheus scrape interval.
*/}}
{{- define "supersonic.rateInterval" -}}
{{- default "1m" .Values.serverLoadRateInterval -}}
{{- end -}}

{{/*
Healthy Triton endpoints as seen by Envoy.
*/}}
{{- define "supersonic.healthyReplicasExpr" -}}
max(envoy_cluster_membership_healthy{release=~"{{ include "supersonic.name" . }}", envoy_cluster_name="triton_grpc_service"})
{{- end -}}

{{/*
Get default scaling metric (extensive form: replicas needed)
*/}}
{{- define "supersonic.defaultMetric" -}}
{{- if not ( eq .Values.serverLoadMetric "" ) }}
  {{- printf "%s" .Values.serverLoadMetric -}}
{{- else }}
{{- $w := include "supersonic.rateInterval" . }}
sum(rate(envoy_cluster_upstream_rq_time_sum{release=~"{{ include "supersonic.name" . }}", envoy_cluster_name="triton_grpc_service"}[{{ $w }}])) / 1e3
* scalar(clamp_min({{ include "supersonic.healthyReplicasExpr" . }}, 1))
/ clamp_min(
    clamp_min(
      (
        sum(rate(nv_inference_request_duration_us{release=~"{{ include "supersonic.name" . }}"}[{{ $w }}]))
        -
        sum(rate(nv_inference_queue_duration_us{release=~"{{ include "supersonic.name" . }}"}[{{ $w }}]))
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
Get scaling threshold (defaults to 2 if not set)
*/}}
{{- define "supersonic.defaultThreshold" -}}
{{- default 2 .Values.serverLoadThreshold -}}
{{- end -}}

{{/*
Get admission threshold for the Envoy rate limiter (defaults to 3 if not set)
*/}}
{{- define "supersonic.admissionThreshold" -}}
{{- default 3 .Values.serverAdmissionThreshold -}}
{{- end -}}
