#!/usr/bin/env bash
set -euo pipefail

target=$1
# Fresh installations have no installed version to upgrade.
rke2_bin=$(command -v rke2 || true)
if [[ -z $rke2_bin && -x /usr/local/bin/rke2 ]]; then
    rke2_bin=/usr/local/bin/rke2
fi
if [[ -z $rke2_bin ]]; then
    exit 0
fi

installed=$("$rke2_bin" --version)
if [[ $installed =~ ^rke2\ version\ v1\.([0-9]+)\. ]]; then
    current_minor=${BASH_REMATCH[1]}
else
    echo "Cannot determine installed RKE2 version from: $installed" >&2
    exit 1
fi
if [[ $target =~ ^v1\.([0-9]+)\.[0-9]+\+rke2r[0-9]+$ ]]; then
    target_minor=${BASH_REMATCH[1]}
else
    echo "Invalid RKE2 upgrade target: $target" >&2
    exit 1
fi
if (( target_minor < current_minor || target_minor > current_minor + 1 )); then
    echo "RKE2 v1.$current_minor to $target requires a staged upgrade or snapshot restore." >&2
    exit 1
fi
