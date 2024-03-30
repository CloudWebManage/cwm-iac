import os
import base64
import requests
from ruamel import yaml


GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN')
GLOBAL_VALUES_URL = os.environ.get('GLOBAL_VALUES_URL')
CLUSTER_VALUES_URL_TEMPLATE = os.environ.get('CLUSTER_VALUES_URL_TEMPLATE')


def init(chart_path):
    pass


def add_cluster_values(cwm_app, cluster_name, path):
    data = yaml.safe_load(base64.b64decode(requests.get(GLOBAL_VALUES_URL, headers={'Authorization': f'token {GITHUB_TOKEN}'}).json()['content']).decode())
    with open(os.path.join(path, 'cwm_global_values.yaml'), 'w') as f:
        yaml.safe_dump(data.get(cwm_app, {}), f)
    data = yaml.safe_load(base64.b64decode(requests.get(CLUSTER_VALUES_URL_TEMPLATE.format(CLUSTER_NAME=cluster_name), headers={'Authorization': f'token {GITHUB_TOKEN}'}).json()['content']).decode())
    with open(os.path.join(path, 'cwm_cluster_values.yaml'), 'w') as f:
        yaml.safe_dump(data.get(cwm_app, {}), f)
    return ['--values', os.path.join(path, 'cwm_global_values.yaml'), '--values', os.path.join(path, 'cwm_cluster_values.yaml')]


def generate_template(cmd, cwd, data):
    cwm_app = os.environ.get('ARGOCD_ENV_CWM_APP')
    cluster_name = os.environ.get('CLUSTER_NAME')
    if cwm_app and cluster_name:
        cmd = ' '.join([cmd, *add_cluster_values(cwm_app, cluster_name, cwd)])
    return cmd, cwd


def process_value(key, value, data):
    if value['type'] == 'prometheus_additional_scrape_configs_json':
        from .monitoring import get_minio_prometheus_scrape_configs_json
        data[key] = get_minio_prometheus_scrape_configs_json()
    else:
        raise ValueError(f'Unknown type: {value["type"]}')


if __name__ == '__main__':
    # res = add_cluster_values('cwm-worker-ingress', 'cwmc-eu-v2test', '.')
    # print(res)
    data = {}
    process_value('prometheus_scrape_configs', {'type': 'prometheus_additional_scrape_configs_json'}, data)
    print(data)
