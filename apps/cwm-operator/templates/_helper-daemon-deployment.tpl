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
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: {{ $.name | quote }}
  template:
    metadata:
      labels:
        app: {{ $.name | quote }}
    spec:
      serviceAccountName: cwm-worker-operator
      tolerations: {{ toYaml (default (index $.root.Values.tolerations $.name) $.root.Values.tolerations.default) | nindent 8 }}
      containers:
        - name: {{ $.name | quote }}
          image: {{ $.root.Values.operatorImage | quote }}
          args: [{{ $.name | quote }}, "start_daemon"]
          imagePullPolicy: {{ default (index $.root.Values.imagePullPolicy $.name) $.root.Values.imagePullPolicy.default }}
          resources: {{ merge (default $.root.Values.resources.default dict) (default (index $.root.Values.resources $.name) dict) | toYaml | nindent 12 }}
          env:
          {{- if $.root.Values.debug }}
            - name: DEBUG
              value: "yes"
          {{- end }}
          {{- range $key, $value := merge (default $.root.Values.env.default dict) (default (index $.root.Values.env $.name) dict) }}
            - name: {{ $key | squote }}
              value: {{ $value | squote }}
          {{- end }}
          envFrom:
            - secretRef:
                name: global
            - secretRef:
                name: {{ $.name | quote }}
{{- end }}
