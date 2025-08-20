resource "tls_private_key" "github_actions_cwm_worker_cluster_deploy_key" {
  algorithm = "RSA"
}

# this is added manually so we don't have to manage GitHub credentials with Terraform
# resource "github_repository_deploy_key" "github_actions_cwm_worker_cluster" {
#   repository = "cwm-worker-cluster"
#   title = "GitHub Actions"
#   key = tls_private_key.github_actions_cwm_worker_cluster_deploy_key.public_key_openssh
# }

# It should be added to cwm-minio-api actions secret as CWM_WORKER_CLUSTER_DEPLOY_KEY_B64
