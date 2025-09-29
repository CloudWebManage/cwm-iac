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

resource "kubernetes_node_taint" "controlplane_secondaries" {
  field_manager = "Terraform_taint_controlplane_secondaries"
  for_each = toset(var.controlplane_secondary_names)
  metadata {
    name = each.value
  }
  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NoExecute"
  }
}

resource "kubernetes_node_taint" "worker-roles" {
  field_manager = "Terraform_taint_worker_roles"
  force = true
  for_each = var.workers
  metadata {
    name = each.key
  }
  taint {
    key = "cwm-iac-worker-role"
    value = each.value.worker-role
    effect = "NoExecute"
  }
  lifecycle {
    ignore_changes = [taint]  # this is needed so that it won't remove automatically added taints
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
