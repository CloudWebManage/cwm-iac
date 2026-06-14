import time
import sys
import os
import subprocess
import socket
import shlex
from concurrent.futures import ProcessPoolExecutor

import requests

from .. import utils


CDN_API_URL = os.getenv("CDN_API_URL")
CDN_API_USER = os.getenv("CDN_API_USER")
CDN_API_PASS = os.getenv("CDN_API_PASS")
PRIMARY_CDN_API_URL = os.getenv("PRIMARY_CDN_API_URL")
PRIMARY_CDN_API_USER = os.getenv("PRIMARY_CDN_API_USER")
PRIMARY_CDN_API_PASS = os.getenv("PRIMARY_CDN_API_PASS")
SECONDARY_CDN_API_URL = os.getenv("SECONDARY_CDN_API_URL")
SECONDARY_CDN_API_USER = os.getenv("SECONDARY_CDN_API_USER")
SECONDARY_CDN_API_PASS = os.getenv("SECONDARY_CDN_API_PASS")
PRIMARY_CLUSTER_NAME = os.getenv("PRIMARY_CLUSTER_NAME")
SECONDARY_CLUSTER_NAME = os.getenv("SECONDARY_CLUSTER_NAME")
DEFAULT_DOMAINS_SUFFIX = os.getenv("DEFAULT_DOMAINS_SUFFIX")


def api_request(method, path, primary=False, secondary=False, return_res=False, **kwargs):
    if primary:
        assert not secondary, "Cannot specify both primary and secondary"
        assert PRIMARY_CDN_API_URL and PRIMARY_CDN_API_USER and PRIMARY_CDN_API_PASS, "missing primary url and creds env vars"
        cdn_api_url = PRIMARY_CDN_API_URL
        cdn_api_user = PRIMARY_CDN_API_USER
        cdn_api_pass = PRIMARY_CDN_API_PASS
    elif secondary:
        assert SECONDARY_CDN_API_USER and SECONDARY_CDN_API_URL and SECONDARY_CDN_API_PASS, "missing secondary url and creds env vars"
        cdn_api_url = SECONDARY_CDN_API_URL
        cdn_api_user = SECONDARY_CDN_API_USER
        cdn_api_pass = SECONDARY_CDN_API_PASS
    else:
        if CDN_API_URL and CDN_API_USER and CDN_API_PASS:
            cdn_api_url = CDN_API_URL
            cdn_api_user = CDN_API_USER
            cdn_api_pass = CDN_API_PASS
        elif PRIMARY_CDN_API_URL and PRIMARY_CDN_API_USER and PRIMARY_CDN_API_PASS:
            cdn_api_url = PRIMARY_CDN_API_URL
            cdn_api_user = PRIMARY_CDN_API_USER
            cdn_api_pass = PRIMARY_CDN_API_PASS
        else:
            raise Exception("Failed to determine api url and creds from env vars")
    cdn_api_url = cdn_api_url.rstrip("/")
    path = path.lstrip("/")
    res = requests.request(
        method,
        f'{cdn_api_url}/{path}',
        auth=(cdn_api_user, cdn_api_pass),
        **kwargs
    )
    if return_res:
        return res
    else:
        if res.status_code < 200 or res.status_code >= 400:
            raise Exception(f"Error {res.status_code}: {res.text}")
        return res.json()


def create_tenant(name, spec, primary=False, secondary=False):
    return api_request("POST", f"apply?cdn_tenant_name={name}", json=spec, primary=primary, secondary=secondary)


def get_tenant(name, primary=False, secondary=False, wait_for=None, progress=None, wait_for_num=0):
    return utils.wait_for(
        lambda: api_request("GET", f"get?cdn_tenant_name={name}", primary=primary, secondary=secondary)['tenant'],
        wait_for=wait_for,
        progress=progress,
        wait_for_num=wait_for_num
    )


def test_tenant_request(domain, path="/anything/hello/world", ip=None, insecure=False):
    path = f'{path}?cb={time.time()}'
    if ip:
        cmd = [
            "curl",
            "-fsvk",
            "--resolve", f"{domain}:443:{ip}",
            "-H", f"Host: {domain}",
            f"https://{domain}{path}"
        ]
        print(shlex.join(cmd), file=sys.stderr)
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    else:
        args = "-fsv"
        if insecure:
            args += "k"
        cmd = ["curl", args, f"https://{domain}{path}"]
        print(shlex.join(cmd), file=sys.stderr)
        p = subprocess.run(["curl", args, f"https://{domain}{path}"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return p.returncode, p.stdout.decode(), p.stderr.decode() if p.returncode != 0 else None


def test_tenant_get_requests(name, path="/anything/hello/world"):
    primary_edge_domain = f'edge.{PRIMARY_CLUSTER_NAME}.{DEFAULT_DOMAINS_SUFFIX}'
    primary_edge_ip = socket.gethostbyname(primary_edge_domain)
    secondary_edge_domain = f'edge.{SECONDARY_CLUSTER_NAME}.{DEFAULT_DOMAINS_SUFFIX}'
    secondary_edge_ip = socket.gethostbyname(secondary_edge_domain)
    requests = {}
    for domain in get_tenant(name)["domains"]:
        domain_name = domain["name"]
        insecure = domain["tlsStatus"]["mode"] == "provided"
        requests[domain_name + (' (insecure)' if insecure else '')] = {"domain": domain_name, "path": path, "insecure": insecure}
        requests[f"{domain_name} - primary ({primary_edge_domain})"] = {"domain": domain_name, "path": path, "ip": primary_edge_ip}
        requests[f"{domain_name} - secondary ({secondary_edge_domain})"] = {"domain": domain_name, "path": path, "ip": secondary_edge_ip}
    return requests


def test_tenant_concurrent(name, concurrency, concurrent_requests, path=f"/anything/hello/world"):
    with ProcessPoolExecutor(max_workers=concurrency) as executor:
        domain_name_futures = {}
        for i in range(concurrent_requests):
            for domain_name, kwargs in test_tenant_get_requests(name, path).items():
                domain_name_futures.setdefault(domain_name, list()).append(executor.submit(test_tenant_request, **kwargs))
        executor.shutdown(wait=True)
        return {domain_name: [f.result() for f in futures] for domain_name, futures in domain_name_futures.items()}


def test_tenant(name, path=f"/anything/hello/world"):
    return {
        name: test_tenant_request(**kwargs)
        for name, kwargs in test_tenant_get_requests(name, path).items()
    }


def delete_tenant(name, primary=False, secondary=False):
    return api_request("POST", f"delete?cdn_tenant_name={name}", primary=primary, secondary=secondary)


def list_tenants():
    return api_request("GET", "list")
