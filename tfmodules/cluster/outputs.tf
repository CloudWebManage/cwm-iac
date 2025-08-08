output "local_files_terraform_remote_state" {
  value = merge(
    module.local_files_ssh_known_hosts_bastion.content,
    module.local_files_ssh_known_hosts_servers.content,
    local.controlplane1_server_name == "" ? {} : module.local_files_admin_kubeconfig[0].content,
  )
}
