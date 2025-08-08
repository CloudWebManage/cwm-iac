output "local_files_terraform_remote_state" {
  value = merge(
    module.local_files_ssh_known_hosts_bastion.content,
    module.local_files_ssh_known_hosts_servers.content,
    module.local_files_admin_kubeconfig.content,
  )
}
