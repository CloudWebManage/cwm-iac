resource "null_resource" "longhorn_init_nodes" {
  for_each = {
    for name, worker in var.workers : name => worker if worker.worker-role == "system" || (var.longhorn_use_systemlogging_role && worker.worker-role == "logging")
  }
  triggers = {
    counter = lookup(var.force_reinstall_counters, "longhorn_init_nodes", 0)
    command = <<-EOT
      set -euo pipefail
      ${var.servers_ssh_command[each.key]} "
        apt-get update -y
        apt-get install -y open-iscsi nfs-common cryptsetup dmsetup
        modprobe iscsi_tcp
        systemctl disable --now rpcbind.socket
        systemctl disable --now rpcbind
        multipath -F || true
        systemctl disable --now multipathd.socket || true
        systemctl disable --now multipathd || true
        cat > /etc/multipath.conf <<'EOF'
        defaults {
          user_friendly_names yes
        }
        blacklist {
          device {
            vendor "LIO-ORG"
            product "*"
          }
        }
        EOF

      "
    EOT
  }
  provisioner "local-exec" {
    command = self.triggers.command
    interpreter = ["bash", "-c"]
  }
}

module "longhorn-app" {
  depends_on = [null_resource.longhorn_init_nodes]
  source    = "../argocd-app"
  name      = "longhorn"
  namespace = "longhorn-system"
  autosync = var.argocd_autosync
  versions = var.versions
  kubeconfig_path = var.admin_kubeconfig_path
  tools = var.tools
  targetRevisionFromVersionByName = true
  values = jsondecode(jsonencode({
    "htpasswdVaultPath" = "${var.vault_path}/longhorn/htpasswd"
    longhorn = {
      ingress = {
        host = "longhorn.${var.ingress_star_domain}"
      }
      global = {
        tolerations = [
          for val in (var.longhorn_use_systemlogging_role ? ["system", "logging"] : ["system"]) :
          {
            key = "cwm-iac-worker-role"
            operator = "Equal"
            value = val
            effect = "NoExecute"
          }
        ]
        nodeSelector = (var.longhorn_use_systemlogging_role ? {
          "cwm-iac-systemlogging-role" = "true"
        } : {
          "cwm-iac-worker-role" = "system"
        })
      }
    }
    overrideSettings = (var.longhorn_use_systemlogging_role ? {
      "taint-toleration" = "cwm-iac-worker-role=system:NoExecute;cwm-iac-worker-role=logging:NoExecute"
      "system-managed-components-node-selector" = "cwm-iac-systemlogging-role:true"
      "default-replica-count" = "1"
    } : {
      "taint-toleration" = "cwm-iac-worker-role=system:NoExecute"
      "system-managed-components-node-selector" = "cwm-iac-worker-role:system"
      "default-replica-count" = "1"
    })
  }))
}

module "longhorn_htpasswd" {
  source = "../htpasswd"
  tools = var.tools
  vault_mount = var.vault_mount
  vault_path = "${var.vault_path}/longhorn/htpasswd"
  vault_kv_put_extra_args = "longhorn_url=\"https://longhorn.${var.ingress_star_domain}\""
  secrets = []
}
