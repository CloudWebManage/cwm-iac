#!/usr/bin/env bash

docker pull ghcr.io/cloudwebmanage/cwm-minio-api-locust:latest
docker rm -f locust || true

systemctl restart locust-ssh-tunnel

. $1

docker run --name locust \
  -d \
  --env-file /root/locust.env --env-file $1 \
  -e SHARED_STATE_REDIS_HOST=172.17.0.1 \
  ghcr.io/cloudwebmanage/cwm-minio-api-locust:latest \
  --worker --master-host 172.17.0.1 $LOCUST_WORKER_ARGS
