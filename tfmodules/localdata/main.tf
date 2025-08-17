terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
    }
  }
}

variable "local_file_path" {
  type = string
  description = "Path to the local file that will be used to store the data."
}

variable "output_content" {
  type = bool
  default = false
  description = "If true, the content of the local file will be outputted in 'content' output."
}

variable "get_remote_script" {
  type = string
  default = "../../bin/terraform/localdata_remote_get.sh"
  description = "Script that gets the data from a remote source and save it to $FILENAME."
}

variable "set_remote_script" {
  type = string
  default = "../../bin/terraform/localdata_remote_set.sh"
  description = "Script that sets the data to a remote source from $FILENAME."
}

variable "generate_script" {
  type = string
  description = "Script that generates the data and saves it to $FILENAME."
}

locals {
  input_hash = sha256(jsonencode({
    local_file_path = var.local_file_path,
    generate_script = var.generate_script
  }))
}

data "external" "main" {
  program = ["bash", "-c", <<-EOT
    set -euo pipefail
    export FILENAME="${var.local_file_path}"
    export INPUT_HASH="${local.input_hash}"
    LOGFILE=$(mktemp)
    trap 'rm -f "$LOGFILE"' EXIT
    if ! [ -f "$FILENAME" ] || ! [ -f "$FILENAME".inputhash ] || [ "$(cat "$FILENAME".inputhash)" != "$INPUT_HASH" ]; then
      ( ${var.get_remote_script} ) >>"$LOGFILE" 2>&1 || true
      if ! [ -f "$FILENAME" ] || ! [ -f "$FILENAME".inputhash ] || [ "$(cat "$FILENAME".inputhash)" != "$INPUT_HASH" ]; then
        ( ${var.generate_script} ) >>"$LOGFILE" 2>&1 || true
        if [ -f "$FILENAME" ]; then
          echo "${local.input_hash}" > "$FILENAME".inputhash
          ( ${var.set_remote_script} ) >>"$LOGFILE" 2>&1 || true
        fi
      fi
    fi
    if [ -f "$FILENAME" ]; then
      echo "Successfully generated or retrieved the file: $FILENAME" >>"$LOGFILE" 2>&1
      if [ "${var.output_content}" = "true" ]; then
        jq -n --rawfile content "$FILENAME" --rawfile log "$LOGFILE" '{content: $content, log: $log}'
      else
        jq -n --arg content "" --rawfile log "$LOGFILE" '{content: $content, log: $log}'
      fi
    else
      echo "Failed to generate or retrieve the file: $FILENAME" >>"$LOGFILE" 2>&1
      jq -n --arg content "" --rawfile log "$LOGFILE" '{content: $content, log: $log}'
    fi
    exit 0
  EOT
  ]
}

resource "terraform_data" "echo_log" {
  depends_on = [data.external.main]
  triggers_replace = {
    log = data.external.main.result.log
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = <<-EOT
      printf "%s\n" "$LOG"
    EOT
    environment = {
      LOG = data.external.main.result.log
    }
  }
}

resource "null_resource" "verify" {
  triggers = {
    input_hash = local.input_hash
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      if ! [ -f "${var.local_file_path}" ]; then
        echo "File ${var.local_file_path} was not generated"
        exit 1
      else
        echo "File ${var.local_file_path} was generated successfully"
        exit 0
      fi
    EOT
    interpreter = ["bash", "-c"]
  }
}

output "content" {
  value = data.external.main.result.content
}
