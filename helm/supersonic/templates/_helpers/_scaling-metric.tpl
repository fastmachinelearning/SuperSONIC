{{/*
Scaling and admission metrics.

The default scaling metric is an "occupancy ratio" derived from Little's law
(L = lambda * W: mean occupancy equals the per-second rate of a cumulative
time counter). It is built from three measured quantities:

  L_envoy   - mean number of requests in flight between Envoy and the Triton
              fleet (queued + executing + on the wire), from Envoy's
              cumulative upstream request-time counter (milliseconds).
  L_service - mean number of requests being actively executed across all
              models and pods, from Triton's cumulative request-duration
              minus queue-duration counters (microseconds).
  R_healthy - number of Triton endpoints Envoy currently routes to
              (max across Envoy pods - each pod reports the same
              upstream cluster membership).

"supersonic.defaultMetric" renders the extensive form

  R_needed = L_envoy / max(L_service / R_healthy, 1)

("how many replicas the current in-flight work needs"), spelled in PromQL as
L_envoy * R_healthy / max(L_service, R_healthy, 1) because clamp_min(v, s)
is PromQL for max(v, s). The floors encode two physical facts: each healthy
replica can serve at least one request concurrently (so serving capacity is
never below R_healthy), and at zero replicas the metric degrades to "requests
in flight" instead of dividing by zero. KEDA consumes this form with
metricType AverageValue: desired = ceil(R_needed / serverLoadThreshold).

"supersonic.admissionMetric" is the same quantity per healthy replica
(R_needed / R_healthy, i.e. the sojourn-time inflation clients experience);
the Envoy Lua filter rejects RepositoryIndex requests when it exceeds
"supersonic.admissionThreshold".

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
