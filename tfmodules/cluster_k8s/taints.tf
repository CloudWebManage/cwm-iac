resource "kubernetes_node_taint" "controlplane1_criticalonly" {
  metadata {
    name = var.controlplane1_node_name
  }
  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NoExecute"
  }
}
