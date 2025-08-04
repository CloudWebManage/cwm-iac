resource "kubernetes_node_taint" "controlplane1" {
  metadata {
    name = var.controlplane1_node_name
  }
  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NoExecute"
  }
}

resource "kubernetes_node_taint" "worker-roles" {
  for_each = var.workers
  metadata {
    name = each.key
  }
  taint {
    key = "cwm-iac-worker-role"
    value = each.value.worker-role
    effect = "NoExecute"
  }
}
