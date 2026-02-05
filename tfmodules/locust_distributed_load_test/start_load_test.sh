#!/usr/bin/env bash

set -euo pipefail

if [ "${1:-}" == "" ] || [ "${2:-}" == "" ] || [ "${3:-}" == "" ] || [ "${4:-}" == "" ] || [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then
  echo 'Usage: $0 <data_path> <name_prefix> <load_test_cluster_name> <worker_server_names>'
  exit 1
fi

DATA_PATH=$1
NAME_PREFIX=$2
LOAD_TEST_CLUSTER_NAME=$3
WORKER_SERVER_NAMES=$4
LOAD_TESTS_DIR="clusters/$LOAD_TEST_CLUSTER_NAME/load_tests"

if [ ! -f "$LOAD_TESTS_DIR/latest.env" ]; then
  echo "latest.env does not exist in env files path $LOAD_TESTS_DIR"
  exit 1
fi

testid=$(date +%Y-%m-%d-%H%M)
echo Starting distributed load test testid $testid
cp "$LOAD_TESTS_DIR/latest.env" "$LOAD_TESTS_DIR/$testid.env"
echo Copying env file to servers
scp -F $DATA_PATH/ssh_config "$LOAD_TESTS_DIR/$testid.env" ${NAME_PREFIX}-main:/root/test$testid.env
for NAME in ${WORKER_SERVER_NAMES}; do
  scp -F $DATA_PATH/ssh_config "$LOAD_TESTS_DIR/$testid.env" ${NAME_PREFIX}-$NAME:/root/test$testid.env
done
echo Starting main server
ssh -F $DATA_PATH/ssh_config ${NAME_PREFIX}-main bash /root/start_main.sh /root/test$testid.env /root/$testid
for NAME in ${WORKER_SERVER_NAMES}; do
  echo "Starting worker $NAME"
  ssh -F $DATA_PATH/ssh_config ${NAME_PREFIX}-$NAME bash /root/start_worker.sh /root/test$testid.env /root/$testid
done
echo Starting SSH tunnel to main server
echo Access the Locust web interface at http://localhost:8089
ssh -F $DATA_PATH/ssh_config -N -L 8089:localhost:8089 ${NAME_PREFIX}-main
