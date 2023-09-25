# Cert Manager

## Deploy

Make sure you are connected to the relevant cluster according to the [cwm-worker-cluster README](https://github.com/CloudWebManage/cwm-worker-cluster/blob/master/README.md)

Create namespace if not exists:

```
kubectl create ns cert-manager
```

Set cluster issuer email (this should be a valid email address, used for identification with Let's Encrypt):

```
export CLUSTER_ISSUER_EMAIL=
```

Deploy

```
kubectl kustomize apps/cert-manager | envsubst | kubectl apply -f -
```

To use - create ingress with TLS and annotation `cert-manager.io/cluster-issuer: "letsencrypt"`
