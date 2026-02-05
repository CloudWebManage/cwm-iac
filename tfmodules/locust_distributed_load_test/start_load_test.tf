output "start_load_test_script" {
  value = <<-EOF
    ../cwm-iac/tfmodules/locust_distributed_load_test/start_load_test.sh \
      "${var.data_path}" \
      "${var.name_prefix}" \
      "${var.cluster_name}" \
      "${join(" ", keys(var.workers))}"
  EOF
}
