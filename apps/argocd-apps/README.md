# ArgoCD Apps

## Deploy

ArgoCD -> Settings -> Repository certificates and known hosts -> Add SSH Known Host:
* Get the github.com known host line:
  * `ssh-keyscan -t rsa github.com`
* Paste the line into the field

ArgoCD -> Settings -> Repositories -> Connect Repo:

* Connection Method: Via SSH
* Name: `cwm-worker-cluster`
* Project: `default`
* Repository URL: `git@github.com:CloudWebManage/cwm-worker-cluster.git`
* SSH Private Key Data:
  * Get it from the management server, the IP and password are in vault under `cwm-worker-clusters-management-server`
  * SSH to the server and run the following to get the private key:
    * `cat ~/.ssh/github-cwm-worker-cluster.id_rsa`
  * Paste the private key into the field

ArgoCD -> Settings -> Repositories -> Connect Repo:

* Connection Method: Via SSH
* Name: `cwm-iac`
* Project: `default`
* Repository URL: `git@github.com:CloudWebManage/cwm-iac.git`
* SSH Private Key Data:
  * Get it from the management server, the IP and password are in vault under `cwm-worker-clusters-management-server`
  * SSH to the server and run the following to get the private key:
    * `cat ~/.ssh/github-cwm-iac.id_rsa`
  * Paste the private key into the field

ArgoCD -> Applications -> New App:

* Application Name: `argocd-apps`
* Project Name: `default`
* Sync Policy: Manual
* Source:
  * Repository URL: `git@github.com:CloudWebManage/cwm-iac.git`
  * Revision: `HEAD`
  * Path: `apps/argocd-apps`
* Destination:
  * Cluster URL: `https://kubernetes.default.svc`
  * Namespace: `argocd`
* Helm
