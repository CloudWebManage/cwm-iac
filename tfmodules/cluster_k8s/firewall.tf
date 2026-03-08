resource "kubernetes_manifest" "firewall_calico_hostendpoint-internal" {
  for_each = var.server_network_interfaces
  manifest = {
    apiVersion = "crd.projectcalico.org/v1"
    kind = "HostEndpoint"
    metadata = {
      name = "internal-${each.key}"
      labels = {
        "interface" = "internal"
        "role" = (var.controlplane1_node_name == each.key || contains(var.controlplane_secondary_names, each.key)) ? "controlplane" : var.workers[each.key]["worker-role"]
      }
    }
    spec = {
      node = each.key
      interfaceName = each.value["int"]["if"]
      expectedIPs = [each.value["int"]["ip"]]
    }
  }
}

resource "kubernetes_manifest" "firewall_calico_hostendpoint-external" {
  for_each = var.server_network_interfaces
  field_manager {
    force_conflicts = true
  }
  manifest = {
    apiVersion = "crd.projectcalico.org/v1"
    kind = "HostEndpoint"
    metadata = {
      name = "external-${each.key}"
      labels = {
        "interface" = "external"
        "role" = (var.controlplane1_node_name == each.key || contains(var.controlplane_secondary_names, each.key)) ? "controlplane" : var.workers[each.key]["worker-role"]
      }
    }
    spec = {
      node = each.key
      interfaceName = each.value["ext"]["if"]
      expectedIPs = [each.value["ext"]["ip"]]
    }
  }
}

resource "kubernetes_manifest" "firewall_global_network_policies" {
  for_each = var.firewall_global_network_policies
  manifest = {
    apiVersion = "crd.projectcalico.org/v1"
    kind = "GlobalNetworkPolicy"
    metadata = {
      name = each.key
    }
    spec = each.value
  }
}
