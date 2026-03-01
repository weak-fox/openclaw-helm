{{/* Expand the name of the chart. */}}
{{- define "openclaw.name" -}}
{{- default .Chart.Name .Values.global.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Create a default fully qualified app name. */}}
{{- define "openclaw.fullname" -}}
{{- if .Values.global.fullnameOverride -}}
{{- .Values.global.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.global.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Chart name and version. */}}
{{- define "openclaw.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{/* Common labels. */}}
{{- define "openclaw.labels" -}}
helm.sh/chart: {{ include "openclaw.chart" . }}
{{ include "openclaw.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Selector labels. */}}
{{- define "openclaw.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openclaw.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Service account name */}}
{{- define "openclaw.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "openclaw.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* OpenClaw API key secret name */}}
{{- define "openclaw.apiKeySecretName" -}}
{{- if .Values.openclaw.secrets.apiKey.existingSecret -}}
{{- .Values.openclaw.secrets.apiKey.existingSecret -}}
{{- else -}}
{{- .Values.openclaw.secrets.apiKey.name -}}
{{- end -}}
{{- end -}}

{{/* Build image repository with optional shared registry prefix. */}}
{{- define "openclaw.imageRepository" -}}
{{- $root := index . "root" -}}
{{- $repo := index . "repo" -}}
{{- $first := (index (splitList "/" $repo) 0) -}}
{{- $isAbsoluteRepo := or (contains "." $first) (contains ":" $first) (eq $first "localhost") -}}
{{- if $isAbsoluteRepo -}}
{{- $repo -}}
{{- else if $root.Values.global.imageRegistry -}}
{{- printf "%s/%s" $root.Values.global.imageRegistry $repo -}}
{{- else -}}
{{- $repo -}}
{{- end -}}
{{- end -}}

{{/* Main OpenClaw image reference */}}
{{- define "openclaw.mainImage" -}}
{{- $repo := include "openclaw.imageRepository" (dict "root" . "repo" .Values.openclaw.image.repository) -}}
{{- printf "%s:%s" $repo .Values.openclaw.image.tag -}}
{{- end -}}

{{/* Sandbox image reference */}}
{{- define "openclaw.sandboxImage" -}}
{{- $repo := include "openclaw.imageRepository" (dict "root" . "repo" .Values.sandbox.image.repository) -}}
{{- printf "%s:%s" $repo .Values.sandbox.image.tag -}}
{{- end -}}

{{/* Seed image reference */}}
{{- define "openclaw.seedImage" -}}
{{- $repo := include "openclaw.imageRepository" (dict "root" . "repo" .Values.openclaw.bootstrap.seedImage.repository) -}}
{{- printf "%s:%s" $repo .Values.openclaw.bootstrap.seedImage.tag -}}
{{- end -}}

{{/* Render OpenClaw config JSON */}}
{{- define "openclaw.configJson" -}}
{{- $providerName := .Values.openclaw.config.modelProvider.provider -}}
{{- $providerModels := list (dict "id" .Values.openclaw.config.modelProvider.model "name" .Values.openclaw.config.modelProvider.model) -}}
{{- if and .Values.openclaw.config.modelProvider.models (gt (len .Values.openclaw.config.modelProvider.models) 0) -}}
{{- $providerModels = .Values.openclaw.config.modelProvider.models -}}
{{- end -}}
{{- $provider := dict
  "baseUrl" .Values.openclaw.config.modelProvider.baseUrl
  "apiKey" "${OPENCLAW_API_KEY}"
  "api" .Values.openclaw.config.modelProvider.api
  "models" $providerModels
-}}
{{- range $key, $value := .Values.openclaw.config.modelProvider.extra }}
{{- $_ := set $provider $key $value -}}
{{- end -}}
{{- $cfg := dict
  "gateway" (dict
    "port" .Values.gateway.service.port
    "mode" "local"
    "trustedProxies" .Values.gateway.trustedProxies
    "controlUi" (dict
      "dangerouslyAllowHostHeaderOriginFallback" .Values.gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback
      "allowInsecureAuth" .Values.gateway.controlUi.allowInsecureAuth
      "dangerouslyDisableDeviceAuth" .Values.gateway.controlUi.dangerouslyDisableDeviceAuth
    )
  )
  "browser" (dict
    "enabled" .Values.sandbox.enabled
    "defaultProfile" "default"
    "profiles" (dict
      "default" (dict "cdpUrl" "http://localhost:8080/cdp" "color" "#4285F4")
      "openclaw" (dict "cdpUrl" "http://localhost:8080/cdp" "color" "#E53935")
    )
  )
  "agents" (dict
    "defaults" (dict
      "workspace" .Values.openclaw.paths.workspaceDir
      "model" (dict "primary" (printf "%s/%s" .Values.openclaw.config.modelProvider.provider .Values.openclaw.config.modelProvider.model))
      "userTimezone" "UTC"
      "timeoutSeconds" 600
      "maxConcurrent" 1
    )
    "list" (list (dict
      "id" "main"
      "default" true
      "identity" (dict "name" "OpenClaw" "emoji" ":lobster:")
    ))
  )
  "models" (dict
    "mode" "merge"
    "providers" (dict $providerName $provider)
  )
  "session" (dict
    "scope" "per-sender"
    "store" .Values.openclaw.paths.sessionsDir
    "reset" (dict "mode" "idle" "idleMinutes" 60)
  )
  "logging" (dict
    "level" "info"
    "consoleLevel" "info"
    "consoleStyle" "compact"
    "redactSensitive" "tools"
  )
  "tools" (dict
    "profile" "full"
    "exec" (dict "host" .Values.openclaw.config.tools.execHost)
    "web" (dict
      "search" (dict "enabled" false)
      "fetch" (dict "enabled" true)
    )
  )
-}}
{{- $pluginsEntries := dict -}}
{{- range $entry := .Values.openclaw.plugins.runtimeEntries }}
{{- $_ := set $pluginsEntries $entry.id (dict "enabled" $entry.enabled "config" $entry.config) -}}
{{- end -}}
{{- if gt (len $pluginsEntries) 0 -}}
{{- $_ := set $cfg "plugins" (dict "entries" $pluginsEntries) -}}
{{- end -}}
{{- $cfg | mustToPrettyJson -}}
{{- end -}}

{{/* Validation rules */}}
{{- define "openclaw.validate" -}}
{{- if ne (int .Values.workload.replicaCount) 1 -}}
{{- fail "OpenClaw only supports workload.replicaCount=1." -}}
{{- end -}}
{{- if and .Values.openclaw.secrets.apiKey.create .Values.openclaw.secrets.apiKey.existingSecret -}}
{{- fail "Set only one of openclaw.secrets.apiKey.create=true or openclaw.secrets.apiKey.existingSecret." -}}
{{- end -}}
{{- if and (not .Values.openclaw.secrets.apiKey.create) (empty .Values.openclaw.secrets.apiKey.existingSecret) -}}
{{- fail "You must provide openclaw.secrets.apiKey.existingSecret or enable openclaw.secrets.apiKey.create." -}}
{{- end -}}
{{- if and .Values.openclaw.secrets.apiKey.create (empty .Values.openclaw.secrets.apiKey.value) -}}
{{- fail "openclaw.secrets.apiKey.value cannot be empty when openclaw.secrets.apiKey.create=true." -}}
{{- end -}}
{{- end -}}
