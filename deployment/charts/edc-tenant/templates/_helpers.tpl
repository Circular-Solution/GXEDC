{{- define "edc-tenant.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 50 | trimSuffix "-" -}}
{{- end -}}

{{- define "edc-tenant.controlplane" -}}
{{- printf "%s-controlplane" (include "edc-tenant.name" .) -}}
{{- end -}}

{{- define "edc-tenant.dataplane" -}}
{{- printf "%s-dataplane" (include "edc-tenant.name" .) -}}
{{- end -}}

{{- define "edc-tenant.image" -}}
{{- $repo := index . 1 -}}
{{- $v := (index . 0).Values -}}
{{- if $v.image.registry -}}
{{- printf "%s/%s:%s" $v.image.registry $repo $v.image.tag -}}
{{- else -}}
{{- printf "%s:%s" $repo $v.image.tag -}}
{{- end -}}
{{- end -}}

{{- define "edc-tenant.javaOpts" -}}
{{- $opts := list -}}
{{- if .Values.useSVE }}{{- $opts = append $opts "-XX:UseSVE=0" -}}{{- end -}}
{{- if .Values.debug }}{{- $opts = append $opts (printf "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=%v" .Values.ports.debug) -}}{{- end -}}
{{- $opts = append $opts "-Dsun.net.http.allowRestrictedHeaders=true" -}}
{{- join " " $opts -}}
{{- end -}}

{{- define "edc-tenant.nodePort" -}}
{{- $base := (index . 0).Values.service.nodePortBase -}}
{{- if $base }}
nodePort: {{ add $base (index . 1) }}
{{- end }}
{{- end -}}
