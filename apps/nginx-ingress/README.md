# Nginx Ingress

## Deploy

Make sure you are connected to the relevant cluster according to the [cwm-worker-cluster README](https://github.com/CloudWebManage/cwm-worker-cluster/blob/master/README.md)

Deploy

```
kubectl kustomize apps/nginx-ingress | kubectl apply -f -
```
