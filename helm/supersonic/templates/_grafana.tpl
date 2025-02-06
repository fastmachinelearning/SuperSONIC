{{/*
Get Grafana name
*/}}
{{- define "supersonic.grafanaName" -}}
{{- printf "%s-grafana" (include "supersonic.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Check if Grafana exists in the namespace (from any release)
*/}}
{{- define "supersonic.grafanaExists" -}}
{{- $root := . -}}
{{- $exists := false -}}
{{- if (lookup "v1" "Service" .Release.Namespace "") -}}
  {{- range (lookup "v1" "Service" .Release.Namespace "").items -}}
    {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "supersonic") 
               (eq (index .metadata.labels "app.kubernetes.io/component") "grafana")
               (ne (index .metadata.labels "app.kubernetes.io/instance") (include "supersonic.name" $root))}}
      {{- $exists = true -}}
      {{- break -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $exists -}}
{{- end -}}

{{/*
Get existing Grafana service name (from any release)
*/}}
{{- define "supersonic.existingGrafanaName" -}}
{{- $root := . -}}
{{- range (lookup "v1" "Service" .Release.Namespace "").items }}
  {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "supersonic") 
             (eq (index .metadata.labels "app.kubernetes.io/component") "grafana")
             (ne (index .metadata.labels "app.kubernetes.io/instance") (include "supersonic.name" $root))}}
    {{- .metadata.name -}}
    {{- break }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Get Grafana URL (handles ingress, existing, and new instances)
*/}}
{{- define "supersonic.grafanaUrl" -}}
{{- if and .Values.grafana.ingress.enabled .Values.grafana.ingress.hostName -}}
https://{{ .Values.grafana.ingress.hostName }}
{{- else -}}
  {{- $foundIngress := false -}}
  {{- if (lookup "networking.k8s.io/v1" "Ingress" .Release.Namespace "") -}}
    {{- $root := . -}}
    {{- range (lookup "networking.k8s.io/v1" "Ingress" .Release.Namespace "").items -}}
      {{- if and (eq (index .metadata.labels "app.kubernetes.io/name") "supersonic") 
                 (eq (index .metadata.labels "app.kubernetes.io/component") "grafana")
                 (ne (index .metadata.labels "app.kubernetes.io/instance") (include "supersonic.name" $root))}}
        {{- range .spec.rules -}}
          {{- if .host -}}
            {{- $foundIngress = true -}}
https://{{ .host }}
            {{- break -}}
          {{- end -}}
        {{- end -}}
        {{- break -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- if not $foundIngress -}}
    {{- if (eq (include "supersonic.grafanaExists" .) "true") -}}
http://{{ include "supersonic.existingGrafanaName" . }}.{{ .Release.Namespace }}.svc.cluster.local
    {{- else -}}
http://{{ include "supersonic.grafanaName" . }}.{{ .Release.Namespace }}.svc.cluster.local
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}} 