resource "local_file" "start_load_test" {
  filename = "${var.data_path}/start_load_test.sh"
  content = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail
    echo Starting distributed load test
    echo Starting main server
    ssh -F ${var.data_path}/ssh_config ${var.name_prefix}-main bash /root/start_main.sh
    for NAME in ${join(" ", keys(var.workers))}; do
      echo "Starting worker $NAME"
      ssh -F ${var.data_path}/ssh_config ${var.name_prefix}-$NAME bash /root/start_worker.sh
    done
    echo Starting SSH tunnel to main server
    echo Access the Locust web interface at http://localhost:8089
    ssh -F ${var.data_path}/ssh_config -N -L 8089:localhost:8089 ${var.name_prefix}-main
  EOT
  file_permission = "0755"
}

output "start_load_test_script_path" {
  value = local_file.start_load_test.filename
}
