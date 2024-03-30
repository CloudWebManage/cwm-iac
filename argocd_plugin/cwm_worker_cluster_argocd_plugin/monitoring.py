import sys
import json
import base64
import traceback
import subprocess
from ruamel import yaml


MC_EXEC_ARGS = ['kubectl', 'exec', '-n', 'minio-tenant-main', '-c', 'minio', 'service/minio', '--', 'mc']


def mc_check_call(*args):
    subprocess.check_call([*MC_EXEC_ARGS, *args], stdout=sys.stderr)


def mc_check_output_yaml(*args):
    return yaml.safe_load(subprocess.check_output([*MC_EXEC_ARGS, *args]))


def get_minio_creds():
    creds = json.loads(subprocess.check_output(['kubectl', '-n', 'minio-tenant-main', 'get', 'secret', 'creds', '-o', 'json']))
    access_key = base64.b64decode(creds['data']['accesskey']).decode()
    secret_key = base64.b64decode(creds['data']['secretkey']).decode()
    return access_key, secret_key


def get_minio_prometheus_scrape_configs_json():
    print('get_minio_prometheus_scrape_configs_json', file=sys.stderr)
    all_scrape_configs = []
    try:
        access_key, secret_key = get_minio_creds()
        mc_check_call('alias', 'set', '--insecure', 'tenant', 'http://localhost:9000', access_key, secret_key)
        try:
            for job_type in ['cluster', 'bucket', 'resource']:
                scrape_configs = mc_check_output_yaml('admin', 'prometheus', 'generate', 'tenant', job_type)['scrape_configs']
                scrape_configs[0]['static_configs'][0]['targets'] = ['minio.minio-tenant-main.svc.cluster.local:80']
                all_scrape_configs.append(scrape_configs[0])
        finally:
            mc_check_call('alias', 'remove', 'tenant')
    except:
        print(traceback.format_exc(), file=sys.stderr)
    return json.dumps(all_scrape_configs)
