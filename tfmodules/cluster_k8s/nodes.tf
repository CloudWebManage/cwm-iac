resource "kubernetes_node_taint" "controlplane1" {
  field_manager = "Terraform_taint_controlplane1"
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
  field_manager = "Terraform_taint_worker_roles"
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

resource "kubernetes_labels" "node_worker_role" {
  field_manager = "Terraform_labels_node_worker_role"
  for_each = var.workers
  api_version = "v1"
  kind = "Node"
  metadata {
    name = each.key
  }
  labels = {
    "cwm-iac-worker-role" = each.value["worker-role"]
  }
}
