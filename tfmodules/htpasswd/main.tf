variable "data_path_htpasswd_filename" {
  type = string
}

variable "secrets" {
  type = list(object({
    name  = string
    namespace = string
  }))
}

resource "random_password" "username" {
  length = 8
  special = false
}
resource "random_password" "password" {
  length = 24
  special = false
}

module "localdata_htpasswd" {
  depends_on = [random_password.username, random_password.password]
  source = "../localdata"
  local_file_path = var.data_path_htpasswd_filename
  output_content = true
  generate_script = <<-EOT
    htpasswd -bn "${random_password.username.result}" "${random_password.password.result}" \
      > "$FILENAME"
  EOT
}

resource "kubernetes_secret" "htpasswd" {
  for_each = {for secret in var.secrets : "${secret.name}-${secret.namespace}" => secret}
  metadata {
    name      = each.value.name
    namespace = each.value.namespace
  }
  type = "Opaque"
  data = {
    auth = module.localdata_htpasswd.content
  }
}

output "username" {
  value = random_password.username.result
  sensitive = true
}

output "password" {
  value = random_password.password.result
  sensitive = true
}

output "content" {
  value = module.localdata_htpasswd.content
}
