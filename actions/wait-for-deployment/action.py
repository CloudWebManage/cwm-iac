import os
import time
import json
from copy import deepcopy

import requests


INPUT_JSON = os.getenv("INPUT_JSON")
WAIT_FOR_TIMEOUT_SECONDS = int(os.getenv("WAIT_FOR_TIMEOUT_SECONDS", "900"))
WAIT_SLEEP_SECONDS = int(os.getenv("WAIT_SLEEP_SECONDS", "5"))


def check_openapi_version(url, username, password, expected_version):
    msg_prefix = f'check_openapi_version {url}:'
    res = requests.get(os.path.join(url, 'openapi.json'), auth=(username, password))
    if res.status_code != 200:
        print(f"{msg_prefix} waiting... invalid status code\n{res.status_code} {res.text}")
        return False
    try:
        actual_version = res.json()['info']['version']
    except Exception:
        print(f"{msg_prefix} waiting... failed to parse\n{res.text}")
        return False
    if actual_version != expected_version:
        print(f"{msg_prefix} waiting... not expected version\n{expected_version} != {actual_version}")
        return False
    print(f"{msg_prefix} ready\n{expected_version}")
    return True


def check_wait_for(wait_for_config):
    wait_for_config = deepcopy(wait_for_config)
    wait_for_type = wait_for_config.pop("type")
    wait_for_func = {
        "openapi_version": check_openapi_version
    }.get(wait_for_type)
    assert wait_for_func, f"Unknown wait-for type: {wait_for_type}"
    return wait_for_func(**wait_for_config)


def main():
    config = json.loads(INPUT_JSON)
    ready = set()
    start_time = time.time()
    while True:
        for i, wait_for_config in enumerate(config["wait-for"]):
            if i not in ready:
                if check_wait_for(wait_for_config):
                    ready.add(i)
        if len(ready) == len(config["wait-for"]):
            break
        if time.time() - start_time > WAIT_FOR_TIMEOUT_SECONDS:
            raise Exception("Timeout waiting for deployment")
        time.sleep(WAIT_SLEEP_SECONDS)


if __name__ == "__main__":
    main()
