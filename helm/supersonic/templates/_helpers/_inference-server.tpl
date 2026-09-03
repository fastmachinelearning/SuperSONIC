{{- /* templates/_helpers/_inference-server.tpl */ -}}

{{/*
Inference server implementation, defaulting to Triton.
*/}}
{{- define "supersonic.inferenceServerType" -}}
{{- .Values.inferenceServer.type | default "triton" -}}
{{- end -}}

{{/*
True when the configured inference server is Nereid.
*/}}
{{- define "supersonic.nereidEnabled" -}}
{{- if eq (include "supersonic.inferenceServerType" .) "nereid" -}}true{{- end -}}
{{- end -}}

{{/*
Reject an unknown inferenceServer.type before it produces a confusing
half-configured Deployment.
*/}}
{{- define "supersonic.validateInferenceServerType" -}}
{{- $type := include "supersonic.inferenceServerType" . -}}
{{- if not (has $type (list "triton" "nereid")) -}}
{{- fail (printf "Unknown inferenceServer.type %q. Supported values: triton, nereid." $type) -}}
{{- end -}}
{{- end -}}

{{/*
Render one probe body from a values block.

The handler is whichever one of these the block sets:
  command:    exec shorthand, a bare command list
  exec:       full exec handler
  httpGet:    HTTP handler
  tcpSocket:  TCP handler

Exactly one may be set. Helm deep-merges values, so a values file that adds a
handler does *not* drop the one this chart defaults to -- switching handler
type means nulling the inherited key (`command: null`). Setting two is
therefore almost always that mistake rather than an intent, and picking one by
precedence would silently probe the wrong endpoint, so it fails instead.

Triton is probed over its HTTP port; Nereid's image ships no curl, so it uses
httpGet against the KServe v2 health endpoints on its own HTTP port.

Usage: include "supersonic.inferenceServerProbe" .Values.inferenceServer.readinessProbe
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
{{- fail (printf "A probe sets more than one handler (%s). Set exactly one; because Helm merges values with the chart defaults, switching handler type means nulling the inherited key, e.g. `command: null`." (join ", " $set)) -}}
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
