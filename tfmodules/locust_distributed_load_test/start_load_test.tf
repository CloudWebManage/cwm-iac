resource "local_file" "start_load_test" {
  filename = "${var.data_path}/start_load_test.sh"
  content = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail

    if [ "$${1:-}" == "" ] || [ "$${1:-}" == "--help" ] || [ "$${1:-}" == "-h" ]; then
      echo 'Usage: $0 <env_file_path>'
      echo "env_file_path is path to an env format file containing the relevant load test configurations as environment variables"
      exit 1
    fi

    echo Starting distributed load test with env file $1
    testid=$(date +%Y%m%d%H%M%S)
    echo Copying env file to servers as test$testid.env
    scp -F ${var.data_path}/ssh_config "$1" ${var.name_prefix}-main:/root/test$testid.env
    for NAME in ${join(" ", keys(var.workers))}; do
      scp -F ${var.data_path}/ssh_config "$1" ${var.name_prefix}-$NAME:/root/test$testid.env
    done
    echo Starting main server
    ssh -F ${var.data_path}/ssh_config ${var.name_prefix}-main bash /root/start_main.sh /root/test$testid.env
    for NAME in ${join(" ", keys(var.workers))}; do
      echo "Starting worker $NAME"
      ssh -F ${var.data_path}/ssh_config ${var.name_prefix}-$NAME bash /root/start_worker.sh /root/test$testid.env
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
