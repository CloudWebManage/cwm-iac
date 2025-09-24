#!/usr/bin/env bash

set -euo pipefail

for f in /docker-entrypoint.d/*; do
    case "$f" in
        *.sh)     echo "running $f"; . "$f" ;;
        *.py)     echo "running $f"; python3 "$f" ;;
    esac
    echo OK
done

exec openresty -g "daemon off;"
