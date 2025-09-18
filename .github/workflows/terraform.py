import os
import io
import sys
import tarfile
from glob import glob
from pathlib import Path

import requests


BASE = "https://app.terraform.io/api/v2"
ORG_NAME = os.getenv("ORG_NAME")
TFC_TOKEN = os.getenv("TFC_TOKEN")


def _tar_gz_bytes(module_path):
    p = Path(module_path)
    if not p.is_dir():
        raise ValueError(f"module_path not a directory: {module_path}")
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        # add contents so they appear at archive root
        for root, _, files in os.walk(p):
            for f in files:
                full = Path(root) / f
                arcname = str(full.relative_to(p))
                if arcname.startswith('.terraform'):
                    continue
                tar.add(full, arcname=arcname)
    buf.seek(0)
    return buf


def publish_module(name, version):
    print(f'Publishing {name} {version}...')
    provider = "generic"
    module_path = f"./tfmodules/{name}"
    h = {
        "Authorization": f"Bearer {TFC_TOKEN}",
        "Content-Type": "application/vnd.api+json",
    }
    r = requests.get(
        f"{BASE}/organizations/{ORG_NAME}/registry-modules/private/{ORG_NAME}/{name}/{provider}", headers=h
    )
    if r.status_code == 404:
        r = requests.post(
            f"{BASE}/organizations/{ORG_NAME}/registry-modules", headers=h, json={
                "data": {
                    "type": "registry-modules",
                    "attributes": {
                        "name": name,
                        "provider": provider,
                        "registry-name": "private",
                    },
                }
            }
        )
        assert r.status_code == 201, f'{r.status_code}: {r.text}'
    else:
        assert r.status_code == 200, f'{r.status_code}: {r.text}'
    r = requests.post(
        f"{BASE}/organizations/{ORG_NAME}/registry-modules/private/{ORG_NAME}/{name}/{provider}/versions", headers=h, json={
            "data": {
                "type": "registry-module-versions", "attributes": {
                    "version": version
                }
            }
        }
    )
    assert r.status_code == 201, f'{r.status_code}: {r.text}'
    upload_url = r.json()["data"]["links"]["upload"]
    buf = _tar_gz_bytes(module_path)
    r = requests.put(upload_url, data=buf, headers={"Content-Type": "application/octet-stream"})
    assert r.status_code == 200, f'{r.status_code}: {r.text}'
    print("OK")


def main(version):
    for p in glob("./tfmodules/*"):
        if os.path.isdir(p):
            name = os.path.basename(p)
            publish_module(name, version)


if __name__ == "__main__":
    main(*sys.argv[1:])
