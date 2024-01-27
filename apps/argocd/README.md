# ArgoCD

### Initial Deployment

Following steps are only required on initial deployment.

Create namespace:

```
kubectl create ns argocd
```

Create an approle in Vault:

* Login with root token
* The following should already be configured, so just verify it:
  * Enabled approle auth method with `approle/` path
  * Enabled kv v2 secrets engine with `kv/` path
* Create a policy named `CLUSTER_NAME`:
```
path "kv/data/CLUSTER_NAME/*" {
  capabilities = [ "create", "list", "read", "update" ]
}
```
* Click on the CLI icon on the top right and run the following commands:
  * `write auth/approle/role/CLUSTER_NAME token_ttl=1h token_max_ttl=4h policies=CLUSTER_NAME`
  * `read auth/approle/role/CLUSTER_NAME/role-id`
  * `write auth/approle/role/CLUSTER_NAME/secret-id -force`

Create a Secret with the vault approle details:

```
kubectl -n argocd create secret generic vault-approle \
  --from-literal=role_id=ROLE_ID \
  --from-literal=secret_id=SECRET_ID \
  --from-literal=addr=VAULT_ADDR
```

Create a Secret with additional cwm secrets (replace the placeholders):

```
kubectl -n argocd create secret generic cwm \
  --from-literal=GITHUB_TOKEN=<vault: github_kamatera_machine_user/github_token_repo_permissions> \
  --from-literal=GLOBAL_VALUES_URL=<vault: cwm-worker-cluster-global-secrets/github_api_global_values_url> \
  --from-literal=CLUSTER_VALUES_URL_TEMPLATE=<vault: cwm-worker-cluster-global-secrets/github_api_cluster_values_url_template>
```

Proceed to the "Deploy" section below, then save the auto-generated Argocd admin password in Vault:

```
cwm-worker-cluster vault write "kv/data/${CLUSTER_NAME}/argocd" '{"password": "'$(kubectl -n argocd get secret argocd-initial-admin-secret -ojson | jq -r .data.password | base64 -d)'"}'
```

## Deploy

Make sure you are connected to the relevant cluster according to [cwm-worker-cluster README](https://github.com/CloudWebManage/cwm-worker-cluster/blob/master/README.md)

```
kubectl kustomize apps/argocd | envsubst '${CLUSTER_NAME} ${CWMC_DOMAIN}' | kubectl apply -n argocd -f -
```

## Access

https://argocd.CWMC_DOMAIN

username: admin
password: Vault path CLUSTER_NAME/argocd
