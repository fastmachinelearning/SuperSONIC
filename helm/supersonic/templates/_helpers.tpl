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
{{- if .Values.prometheus.ingress.enabled -}}
https://{{ .Values.prometheus.ingress.hostName }}
{{- else -}}
http://{{ include "supersonic.prometheusName" . }}.{{ .Release.Namespace }}.svc.cluster.local:9090
{{- end -}}
{{- else if .Values.prometheus.url -}}
{{ .Values.prometheus.scheme }}://{{ .Values.prometheus.url }}
{{- end }}
{{- end }}

{{- define "supersonic.validateRBACPermissions" -}}
{{- if not .Values.prometheus.external -}}
  {{- $canReadRoles := false -}}
  {{- if (lookup "rbac.authorization.k8s.io/v1" "Role" .Release.Namespace "") -}}
    {{- $canReadRoles = true -}}
  {{- end -}}
  {{- if not $canReadRoles -}}
    {{- fail "\nError: Failed to install Prometheus due to lack of permissions to get 'roles' in API group 'rbac.authorization.k8s.io'.\nEither:\n1. Set prometheus.external=true in value.yaml and provide an external Prometheus URL, or\n2. Request necessary RBAC permissions from your cluster administrator." -}}
  {{- end -}}
{{- end -}}
{{- end -}}