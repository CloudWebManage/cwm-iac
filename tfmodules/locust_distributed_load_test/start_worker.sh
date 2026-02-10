#!/usr/bin/env bash

docker rm -f locust || true
docker pull ghcr.io/cloudwebmanage/cwm-minio-api-locust:latest

systemctl restart locust-ssh-tunnel

. $1

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
  ghcr.io/cloudwebmanage/cwm-minio-api-locust:latest \
  --worker --master-host 172.17.0.1 $LOCUST_WORKER_ARGS
