#!/usr/bin/env bash

set -euo pipefail

[ "${KAMATERA_API_CLIENT_ID:-}" == "" ] && echo missing KAMATERA_API_CLIENT_ID env var && exit 1
[ "${KAMATERA_API_SECRET:-}" == "" ] && echo missing KAMATERA_API_SECRET env var && exit 1

SERVER_NAME="${1}"

[ "${SERVER_NAME}" == "" ] && echo missing SERVER_NAME arg && exit 1

SERVER_ID="$(cloudcli --api-clientid ${KAMATERA_API_CLIENT_ID} --api-secret ${KAMATERA_API_SECRET} server info --name=$SERVER_NAME --format json | jq -r '.[0].id')"

[ "${SERVER_ID}" == "" ] && echo missing SERVER_ID && exit 1

curl "https://console.clubvps.com/svc/server/${SERVER_ID}/firewall" \
  -X 'PUT' \
  -H "AuthClientId: ${KAMATERA_API_CLIENT_ID}" \
  -H "AuthSecret: ${KAMATERA_API_SECRET}" \
  --data-raw '{"rules":[],"ipSets":[],"aliases":[],"fwac":1,"nics":[]}'

echo
echo "Firewall disabled for server ${SERVER_NAME} (${SERVER_ID})"
