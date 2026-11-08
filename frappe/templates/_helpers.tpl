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
Create the name of the service account to use
*/}}
{{- define "frappe.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "frappe.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create redis host name
*/}}
{{- define "redis.fullname" -}}
{{- printf "%s-%s" .Release.Name "redis" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Gets the mariadb host name
*/}}
{{- define "frappe.mariadbHost" -}}
{{ .Values.mariadbHost }}
{{- end -}}

{{/*
Gets the redis socketio host name
*/}}
{{- define "frappe.redisSocketIOHost" -}}
{{ .Values.redisSocketIOHost }}
{{- end -}}

{{/*
Gets the redis queue host name
*/}}
{{- define "frappe.redisQueueHost" -}}
{{ .Values.redisQueueHost }}
{{- end -}}

{{/*
Gets the redis cache host name
*/}}
{{- define "frappe.redisCacheHost" -}}
{{ .Values.redisCacheHost }}
{{- end -}}

{{/*
Init container that creates and chowns the persistence subPath directories, so
a fresh subPath (otherwise created root-owned by the kubelet) is writable by
the non-root frappe user before the main containers start. Renders nothing
unless a subPath is set. Takes a dict with "root" (the chart context) and
"logs" (whether the pod mounts the logs volume).
*/}}
{{- define "frappe.subPathInitContainer" -}}
{{- $root := .root -}}
{{- $p := $root.Values.persistence -}}
{{- if $p.subPathPermissions.enabled -}}
{{- $uid := default 1000 $root.Values.securityContext.runAsUser -}}
{{- $withLogs := and .logs $p.logs.subPath -}}
{{- if or $p.worker.subPath $withLogs }}
- name: fix-subpath-permissions
  image: {{ $root.Values.image.repository }}:{{ $root.Values.image.tag }}
  imagePullPolicy: {{ $root.Values.image.pullPolicy }}
  # A failing mkdir fails the init container (for any dir). chown only runs when
  # needed and is non-fatal: on root-squashed volumes (e.g. NFS) it can be
  # rejected even though the dir is writable.
  command: ['/bin/sh', '-c', 'rc=0; for d in "$@"; do if mkdir -p "$d"; then [ "$(stat -c %u "$d")" = "{{ $uid }}" ] || chown {{ $uid }}:{{ $uid }} "$d" || echo "warning: could not chown $d" >&2; else rc=1; fi; done; exit $rc', 'sh']
  {{- /* Dirs are passed as positional args so subPath values are never parsed by the shell. */}}
  args:
    {{- if $p.worker.subPath }}
    - {{ printf "/mnt/sites/%s" (toString $p.worker.subPath) | quote }}
    {{- end }}
    {{- if $withLogs }}
    - {{ printf "/mnt/logs/%s" (toString $p.logs.subPath) | quote }}
    {{- end }}
  securityContext:
    # run as root to set ownership
    runAsNonRoot: false
    runAsUser: 0
  volumeMounts:
    {{- if $p.worker.subPath }}
    - name: sites-dir
      mountPath: /mnt/sites
    {{- end }}
    {{- if $withLogs }}
    - name: logs
      mountPath: /mnt/logs
    {{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Checks for the site-config job. It reads the site the create-site job makes, and
replaces the migrate job, which runs in parallel with create-site.
*/}}
{{- define "frappe.dbRootUser" -}}
{{- if or .Values.mariadb.enabled (get .Values "mariadb-subchart").enabled (get .Values "mariadb-sts").enabled -}}
root
{{- else if or .Values.postgresql.enabled (get .Values "postgresql-subchart").enabled (get .Values "postgresql-sts").enabled -}}
postgres
{{- else -}}
{{- required "dbRootUser is required for an external database" .Values.dbRootUser -}}
{{- end -}}
{{- end -}}

{{- define "frappe.validateSiteConfig" -}}
{{- required "jobs.createSite.siteName is required" .Values.jobs.createSite.siteName | trunc 0 -}}
{{- if not (and .Values.image.repository .Values.image.tag) -}}
{{- fail "image.repository and image.tag are required" -}}
{{- end -}}
{{- if and .Values.siteConfig.seed.enabled (not (and .Values.siteConfig.seed.image.repository .Values.siteConfig.seed.image.tag)) -}}
{{- fail "siteConfig.seed.image.repository and tag are required" -}}
{{- end -}}
{{- if .Values.jobs.migrate.enabled -}}
{{- fail "keep jobs.migrate disabled: the site-config job runs bench migrate after the site exists" -}}
{{- end -}}
{{- $sts := or (get .Values "postgresql-sts").enabled (get .Values "mariadb-sts").enabled -}}
{{- if and $sts .Values.dbHost -}}
{{- fail "dbHost is ignored while postgresql-sts or mariadb-sts is enabled: disable the in-chart database" -}}
{{- end -}}
{{- if not (or $sts .Values.dbHost .Values.mariadb.enabled .Values.postgresql.enabled (get .Values "mariadb-subchart").enabled (get .Values "postgresql-subchart").enabled) -}}
{{- fail "set dbHost or enable an in-chart database" -}}
{{- end -}}
{{- end -}}

{{/* Queues of extraWorkers as the `workers` object of common_site_config.json. */}}
{{- define "frappe.extraWorkersConf" -}}
{{- $workers := dict -}}
{{- range .Values.extraWorkers -}}
{{- range $queue, $timeout := .queues -}}
{{- $_ := set $workers $queue (dict "timeout" $timeout) -}}
{{- end -}}
{{- end -}}
{{- toJson $workers -}}
{{- end -}}
