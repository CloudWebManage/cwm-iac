terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    null = {
      source  = "hashicorp/null"
    }
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [
        aws.route53
      ]
    }
  }
}

variable "controlplane1_node_name" {
  type = string
}

variable "kubeconfig_path" {
  type = string
}

variable "versions" {
  type = map(string)
}

variable "data_path" {
  type = string
}

variable "force_reinstall_counters" {
  type = map(number)
}

variable "workers" {
  type = map(object({
    worker-role = string  # system - used for system / management workloads
                          # any other value is considered an application workload node, it's used to label/taint the nodes
    public-ip = string
  }))
}

variable "tools" {
  type = any
  default = {}
}

# these are private GitHub repos that ArgoCD needs access to
# it will create ssh key for each and set it in argocd repo secret
# you then have to manually add the public key as a deploy key in GitHub with read-only access
variable "argocd_github_repo_deploy_keys" {
  type = map(object({
    repo_slug = string
  }))
}

variable "ingress_nginx_controller_worker_role" {
  type = string
  default = "system"
}

variable "ingress_dns_zone_id" {
  type = string
  default = ""
}

variable "ingress_dns_zone_domain" {
  type = string
  default = ""
}

variable "cluster_name" {
  type = string
}
