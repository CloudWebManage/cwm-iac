#!/usr/bin/env bash

set -euo pipefail

docker rm -f redis || true
docker rm -f locust || true
docker network create locust || true
docker pull ghcr.io/cloudwebmanage/cwm-minio-api-locust:latest

. $1

mkdir -p "${2}"
chmod -R 777 "${2}"
if [ "${CWM_INIT_FROM_JSON_FILE:-}" != "" ]; then
  cp "/root/${CWM_INIT_FROM_JSON_FILE}" "${2}/${CWM_INIT_FROM_JSON_FILE}"
  export CWM_INIT_FROM_JSON_FILE="/tmp/data/${CWM_INIT_FROM_JSON_FILE}"
fi

docker run --name redis -d --network locust -p 127.0.0.1:6379:6379 -v /root/.data/redis:/data redis:8
docker run --name locust --network locust \
  -d -p 127.0.0.1:8089:8089 -p 127.0.0.1:5557:5557 \
  --env-file /root/locust.env --env-file $1 \
  -e SHARED_STATE_REDIS_HOST=redis \
  -v "${2}:/tmp/data" \
  -e CWM_INIT_FROM_JSON_FILE \
  ghcr.io/cloudwebmanage/cwm-minio-api-locust:latest \
  --master $LOCUST_MAIN_ARGS --csv /tmp/data/report

if [ "$(docker exec locust bash -c 'echo $MINIO_API_URL')" != "" ]; then
  echo "setting up minio cwm profile in locust"
  docker exec locust bash -c 'mc alias set cwm "$MINIO_API_URL" "$MINIO_API_ADMIN_USERNAME" "$MINIO_API_ADMIN_PASSWORD"'
fi
