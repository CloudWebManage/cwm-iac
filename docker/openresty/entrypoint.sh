#!/usr/bin/env bash

set -euo pipefail

if ! [ -z "${WORKER_CONNECTIONS:-}" ]; then
  sed -i "s/worker_connections 1024;/worker_connections ${WORKER_CONNECTIONS};/" /usr/local/openresty/nginx/conf/nginx.conf
fi
if ! [ -z "${WORKER_PROCESSES:-}" ]; then
  sed -i "s/worker_processes 2;/worker_processes ${WORKER_PROCESSES};/" /usr/local/openresty/nginx/conf/nginx.conf
fi
if ! [ -z "${ERROR_LOG_LEVEL:-}" ]; then
  sed -i "s/error_log  stderr  error;/error_log  stderr  ${ERROR_LOG_LEVEL};/" /usr/local/openresty/nginx/conf/nginx.conf
fi

exec openresty -g "daemon off;"
