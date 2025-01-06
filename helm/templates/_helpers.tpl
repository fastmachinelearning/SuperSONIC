{{- /* templates/_helpers.tpl */ -}}
{{- define "supersonic.name" -}}
{{- if .Values.nameOverride }}
  {{- printf "%s" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else }}
  {{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- end -}}

{{- define "supersonic.fullname" -}}
{{- if .Values.fullnameOverride }}
  {{- printf "%s" .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else }}
  {{- printf "%s-%s" (include "supersonic.name" .) .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- end -}}

{{- define "supersonic.tritonName" -}}
{{- printf "%s-triton" (include "supersonic.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "supersonic.envoyName" -}}
{{- printf "%s" (include "supersonic.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}