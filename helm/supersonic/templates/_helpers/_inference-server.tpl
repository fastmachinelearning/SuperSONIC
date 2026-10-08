{{/*
Inference server type (triton or nereid)
*/}}
{{- define "supersonic.inferenceServerType" -}}
{{- .Values.inferenceServer.type | default "triton" -}}
{{- end -}}

{{/*
True when the inference server is Nereid
*/}}
{{- define "supersonic.nereidEnabled" -}}
{{- if eq (include "supersonic.inferenceServerType" .) "nereid" -}}true{{- end -}}
{{- end -}}

{{/*
Fail on an unknown inferenceServer.type
*/}}
{{- define "supersonic.validateInferenceServerType" -}}
{{- $type := include "supersonic.inferenceServerType" . -}}
{{- if not (has $type (list "triton" "nereid")) -}}
{{- fail (printf "Unknown inferenceServer.type %q. Supported values: triton, nereid." $type) -}}
{{- end -}}
{{- end -}}

{{/*
Probe body from a values block. One handler may be set: command (exec
shorthand), exec, httpGet or tcpSocket. Helm merges values with the chart
defaults, so switching handler needs the default one nulled.
*/}}
{{- define "supersonic.inferenceServerProbe" -}}
{{- $probe := . -}}
{{- $set := list -}}
{{- range $handler := (list "command" "exec" "httpGet" "tcpSocket") -}}
{{- if index $probe $handler -}}
{{- $set = append $set $handler -}}
{{- end -}}
{{- end -}}
{{- if gt (len $set) 1 -}}
{{- fail (printf "A probe sets more than one handler (%s); null the default one, e.g. `command: null`." (join ", " $set)) -}}
{{- end -}}
{{- if $probe.command }}
exec:
  command: {{ toYaml $probe.command | nindent 4 }}
{{- else if $probe.exec }}
exec:
  {{- toYaml $probe.exec | nindent 2 }}
{{- else if $probe.httpGet }}
httpGet:
  {{- toYaml $probe.httpGet | nindent 2 }}
{{- else if $probe.tcpSocket }}
tcpSocket:
  {{- toYaml $probe.tcpSocket | nindent 2 }}
{{- end }}
{{- range $field := (list "initialDelaySeconds" "periodSeconds" "timeoutSeconds" "successThreshold" "failureThreshold") }}
{{- if hasKey $probe $field }}
{{ $field }}: {{ index $probe $field }}
{{- end }}
{{- end }}
{{- end -}}
