#!/usr/bin/env bash

set -euo pipefail

docker pull ghcr.io/cloudwebmanage/cwm-minio-api-locust:latest
docker rm -f locust || true
docker run --name locust \
  -d -p 127.0.0.1:8089:8089 -p 127.0.0.1:5557:5557 \
  --env-file /root/locust.env \
  ghcr.io/cloudwebmanage/cwm-minio-api-locust:latest \
  --master
