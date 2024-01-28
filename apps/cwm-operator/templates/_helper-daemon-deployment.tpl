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
          imagePullPolicy: {{ default root.Values.imagePullPolicy.default (index root.Values.imagePullPolicy $.name) }}
          resources: {{ merge (default root.Values.resources.default dict) (default (index root.Values.resources $.name) dict) | toYaml | nindent 12 }}
          env:
          {{- range $key, $value := merge (default root.Values.env.default dict) (default (index root.Values.env $.name) dict) }}
          - name: {{ $key | quote }}
            value: {{ $value | quote }}
          {{- end }}
{{- end }}
