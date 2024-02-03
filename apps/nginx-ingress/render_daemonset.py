#!/usr/bin/env python3
import json
import subprocess

obj = json.loads(subprocess.check_output(
    "cat apps/nginx-ingress/deploy.yaml | yq e -o=json '. | select(.kind == \"Deployment\")' -",
    shell=True
))
obj['kind'] = 'DaemonSet'
obj['metadata']['name'] = 'ingress-nginx-daemonset'
del obj['spec']['strategy']
for port in obj['spec']['template']['spec']['containers'][0]['ports']:
    if port['containerPort'] in (80, 443):
        port['hostPort'] = port['containerPort']
obj['spec']['template']['spec']['tolerations'] = [
    {'key': 'cwmc-role', 'value': 'worker', 'effect': 'NoSchedule'},
    {'key': 'cwmc-role', 'value': 'monitoring', 'effect': 'NoSchedule'},
]
print(json.dumps(obj))
