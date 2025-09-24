#!/usr/bin/env bash

set -euo pipefail

python3 /entrypoint.py
exec openresty -g "daemon off;"
