#!/usr/bin/env bash

. /root/locust.env
. $1

LOCUST_DOCKER_IMAGE="${LOCUST_DOCKER_IMAGE:-ghcr.io/cloudwebmanage/cwm-minio-api-locust:latest}"

docker rm -f locust || true
docker pull $LOCUST_DOCKER_IMAGE

systemctl restart locust-ssh-tunnel

mkdir -p "${2}"
chmod -R 777 "${2}"
if [ "${CWM_INIT_FROM_JSON_FILE:-}" != "" ]; then
  cp "/root/${CWM_INIT_FROM_JSON_FILE}" "${2}/${CWM_INIT_FROM_JSON_FILE}"
  export CWM_INIT_FROM_JSON_FILE="/tmp/data/${CWM_INIT_FROM_JSON_FILE}"
fi

docker run --name locust \
  -d \
  --env-file /root/locust.env --env-file $1 \
  -e SHARED_STATE_REDIS_HOST=172.17.0.1 \
  -v "${2}:/tmp/data" \
  -e CWM_INIT_FROM_JSON_FILE \
  $LOCUST_DOCKER_IMAGE \
  --worker --master-host 172.17.0.1 $LOCUST_WORKER_ARGS
