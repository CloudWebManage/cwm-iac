{{/* {{- include "daemon.deployment" (dict "root" $ "name" "nodes-checker") }} */}}
{{- define "daemon.deployment" }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $.name | quote }}
  labels:
    app: {{ $.name | quote }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ $.name | quote }}
  template:
    metadata:
      labels:
        app: {{ $.name | quote }}
    spec:
      containers:
        - name: {{ $.name | quote }}
          image: ghcr.io/cloudwebmanage/cwm-worker-operator/cwm_worker_operator:latest
          args: [{{ $.name | quote }}, "start_daemon"]
          imagePullPolicy: {{ default $.Values.imagePullPolicy.default (index $.Values.imagePullPolicy $.name) }}
          resources: {{ merge (default $.Values.resources.default dict) (default (index $.Values.resources $.name) dict) | toYaml | nindent 12 }}
          env:
          {{- range $key, $value := merge (default $.Values.env.default dict) (default (index $.Values.env $.name) dict) }}
          - name: {{ $key | quote }}
            value: {{ $value | quote }}
          {{- end }}
{{- end }}
