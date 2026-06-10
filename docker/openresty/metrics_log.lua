metric_requests:inc(1, {ngx.var.server_name, ngx.var.status})
metric_latency:observe(tonumber(ngx.var.request_time), {ngx.var.server_name})
metric_response_size:observe(tonumber(ngx.var.bytes_sent), {ngx.var.server_name})
metric_request_size:observe(tonumber(ngx.var.request_length), {ngx.var.server_name})
