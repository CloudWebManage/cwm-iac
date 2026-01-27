#!/usr/bin/env bash

docker pull ghcr.io/cloudwebmanage/cwm-minio-api-locust:latest
docker rm -f locust || true
docker run --name locust \
  -d \
  --env-file /root/locust.env \
  ghcr.io/cloudwebmanage/cwm-minio-api-locust:latest \
  --worker --master-host 172.17.0.1
