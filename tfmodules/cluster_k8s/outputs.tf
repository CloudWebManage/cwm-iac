output "outputs" {
  value = {
    argocd_github_repo_deploy_keys = {
      for k, v in var.argocd_github_repo_deploy_keys : k => {
        repo_slug = v.repo_slug
        public_key = tls_private_key.argocd_github_repo_deploy_keys[k].public_key_openssh
      }
    }
  }
  sensitive = true
}
