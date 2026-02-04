resource "local_file" "start_load_test" {
  filename = "${var.data_path}/start_load_test.sh"
  content = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail

    if [ "$${1:-}" == "" ] || [ "$${1:-}" == "--help" ] || [ "$${1:-}" == "-h" ]; then
      echo 'Usage: $0 <env_files_path>'
      echo "env_files_path is path to a directory containing env files for load tests"
      echo "it must have at least a latest.env file"
      echo "this file will be copied in the same directory to file names YYYY-MM-DD-HHMM.env"
      exit 1
    fi

    if [ ! -f "$1/latest.env" ]; then
      echo "latest.env does not exist in env files path"
      exit 1
    fi

    testid=$(date +%Y-%m-%d-%H%M)
    echo Starting distributed load test testid $testid
    cp "$1/latest.env" "$1/$testid.env"
    echo Copying env file to servers
    scp -F ${var.data_path}/ssh_config "$1/$testid.env" ${var.name_prefix}-main:/root/test$testid.env
    for NAME in ${join(" ", keys(var.workers))}; do
      scp -F ${var.data_path}/ssh_config "$1/$testid.env" ${var.name_prefix}-$NAME:/root/test$testid.env
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
