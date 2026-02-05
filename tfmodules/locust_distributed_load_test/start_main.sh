#!/usr/bin/env bash

set -euo pipefail

docker network create locust || true

docker rm -f redis || true
docker run --name redis -d --network locust -p 127.0.0.1:6379:6379 redis:8

. $1

mkdir -p "${2}"
chmod -R 777 "${2}"

docker pull ghcr.io/cloudwebmanage/cwm-minio-api-locust:latest
docker rm -f locust || true
docker run --name locust --network locust \
  -d -p 127.0.0.1:8089:8089 -p 127.0.0.1:5557:5557 \
  --env-file /root/locust.env --env-file $1 \
  -e SHARED_STATE_REDIS_HOST=redis \
  -v "${2}:/tmp/data" \
  ghcr.io/cloudwebmanage/cwm-minio-api-locust:latest \
  --master $LOCUST_MAIN_ARGS --csv /tmp/data/report
