{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "frappe.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "frappe.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "frappe.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "frappe.labels" -}}
helm.sh/chart: {{ include "frappe.chart" . }}
{{ include "frappe.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "frappe.selectorLabels" -}}
app.kubernetes.io/name: {{ include "frappe.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
PostgreSQL connection for the appDatabases Job, as a dict: host, adminUser, secret, secretKey, image.
The in-chart StatefulSet wins when both are enabled, as in NOTES.txt.
*/}}
{{- define "frappe.postgresAdmin" -}}
{{- $sts := index .Values "postgresql-sts" }}
{{- $sub := index .Values "postgresql-subchart" }}
{{- $subEnabled := or (dig "postgresql" "enabled" false .Values.AsMap) $sub.enabled }}
{{- if $sts.enabled }}
{{- dict "host" (printf "%s-postgresql-sts" (include "frappe.fullname" .)) "adminUser" $sts.postgresUser "secret" (include "frappe.fullname" .) "secretKey" "postgres-password" "image" (printf "%s:%s" $sts.image.repository $sts.image.tag) | toJson }}
{{- else if $subEnabled }}
{{- $auth := $sub.auth | default dict }}
{{- $secret := $auth.existingSecret | default (printf "%s-postgresql-subchart" .Release.Name) }}
{{- $key := "postgres-password" }}
{{- if $auth.existingSecret }}{{- $key = default "postgres-password" ($auth.secretKeys).adminPasswordKey }}{{- end }}
{{- $img := $sub.image | default dict }}
{{- dict "host" (printf "%s-postgresql-subchart" .Release.Name) "adminUser" "postgres" "secret" $secret "secretKey" $key "image" (printf "%s/%s:%s" ($img.registry | default "docker.io") $img.repository $img.tag) | toJson }}
{{- else }}
{{- fail "appDatabases needs PostgreSQL: enable postgresql-sts or postgresql-subchart" }}
{{- end }}
{{- end -}}

{{/*
Secret holding an app database's login: <fullname>-app-<name with _ as ->, or the entry's existingSecret.
*/}}
{{- define "frappe.appDatabaseSecret" -}}
{{- if .db.existingSecret -}}
{{- .db.existingSecret -}}
{{- else -}}
{{- printf "%s-app-%s" (include "frappe.fullname" .root) (.db.name | replace "_" "-") | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
