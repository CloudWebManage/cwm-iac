import sys
import os
import time
import functools
import json
import types
import subprocess
import signal
import datetime

from yaml import safe_load
import requests


PROM_API_URL = os.getenv('PROM_API_URL')  # 'http://prometheus:9090/api'
SEND_NSCA_BINARY = os.getenv("SEND_NSCA_BINARY", os.path.join(os.path.dirname(__file__), "send_nsca_x86_64"))
SEND_NSCA_CONFIG = os.getenv("SEND_NSCA_CONFIG")
SEND_NSCA_HOST = os.getenv("SEND_NSCA_HOST")
STALENESS_THRESHOLD_SECONDS = int(os.getenv("STALENESS_THRESHOLD_SECONDS", "120"))
DAEMON_ITERATIONS_TTL = int(os.getenv("DAEMON_ITERATIONS_TTL", "60"))
CLUSTER_INSTANCE_NAME = os.getenv("CLUSTER_INSTANCE_NAME", "cwmc-local")


@functools.lru_cache()
def get_instances():
    res = {}
    for row_key, row_val in prom_vector_query("node_uname_info", ["instance", "nodename"], parse_instance=False):
        res[row_key['instance']] = row_key['nodename']
    return res


@functools.lru_cache(maxsize=None)
def get_instance_name(instance):
    return get_instances().get(instance, instance)


def prom_vector_query(promql, row_key_labels, parse_instance=True):
    res = requests.get(os.path.join(PROM_API_URL, 'v1', 'query'), params={
        'query': promql,
    }, timeout=15)
    assert res.status_code == 200, res.content
    data = res.json()
    assert data['status'] == 'success'
    assert data['data']['resultType'] == 'vector'
    for row in data['data']['result']:
        row_key = {}
        for label in row_key_labels:
            val = row['metric'][label]
            if parse_instance and label == 'instance':
                val = get_instance_name(val)
            row_key[label] = val
        _, row_val = row['value']
        row_val = float(row_val)
        yield row_key, row_val


def update_rows_staleness(instance, row_val, rows):
    new_staleness_seconds = time.time() - float(row_val)
    old_staleness_seconds = rows.get(instance, {}).get('__staleness_seconds')
    if old_staleness_seconds is None or old_staleness_seconds < new_staleness_seconds:
        rows.setdefault(instance, {})['__staleness_seconds'] = new_staleness_seconds


def get_check_rows(promqls, labels, promql_timestamp):
    has_instance = 'instance' in labels
    rows = {}
    for promql_name, promql in promqls.items():
        for row_key, row_val in prom_vector_query(promql, labels):
            instance = row_key.pop('instance') if has_instance else CLUSTER_INSTANCE_NAME
            if len(row_key) == 0:
                rows.setdefault(instance, {}).setdefault('.', {})[promql_name] = row_val
            else:
                rows.setdefault(instance, {}).setdefault(",".join([f'{k}={v}' for k, v in row_key.items()]), {})[promql_name] = row_val
        if not promql_timestamp:
            for row_key, row_val in prom_vector_query(f'timestamp({promql})', labels):
                instance = row_key.pop('instance') if has_instance else CLUSTER_INSTANCE_NAME
                update_rows_staleness(instance, row_val, rows)
    if promql_timestamp:
        for row_key, row_val in prom_vector_query(promql_timestamp, labels):
            instance = row_key.pop('instance') if has_instance else CLUSTER_INSTANCE_NAME
            update_rows_staleness(instance, row_val, rows)
    return rows


def has_check_state(data, state_eval):
    for valsk in data:
        if not valsk.startswith("__"):
            for k, v in data[valsk].items():
                if not k.startswith('__'):
                    locals()[k] = v
            try:
                if eval(state_eval):
                    return state_eval
            except Exception as e:
                raise Exception(f'failed to evaluate expression:\n{state_eval}\nfor labels:\n{valsk}\nwith data:\n{data[valsk]}') from e
    return None


def get_check_states(config, check_id):
    check = config['checks'][check_id]
    rows = get_check_rows(check['promqls'], check['labels'], check.get('promql_timestamp'))
    has_instance = 'instance' in check['labels']
    checked_instances = set()
    for instance, data in rows.items():
        checked_instances.add(instance)
        check_state, check_msgs = None, [check['title']]
        staleness_seconds = data.get('__staleness_seconds')
        staleness_seconds_threshold = config.get('staleness_seconds_threshold', STALENESS_THRESHOLD_SECONDS)
        if staleness_seconds is None or staleness_seconds > staleness_seconds_threshold:
            check_state = 'critical'
            check_msgs.append(f'Did not receive update from host since at least {staleness_seconds_threshold} seconds ago')
        else:
            for state in ['warning', 'critical']:
                check_state_msg = has_check_state(data, check[state])
                if check_state_msg is not None:
                    check_state = state
                    check_msgs.append(f'state {state} because {check_state_msg}')
                    break
            if (has_instance and len(check['labels']) > 1) or (not has_instance and len(check['labels']) > 0):
                for valsk in data:
                    if not valsk.startswith("__"):
                        check_msgs.append(
                            valsk + ' ' + ' '.join([f'{k}={data[valsk].get(k)}' for k in check['promqls'].keys()]))
            else:
                check_msgs.append(' '.join([f'{k}={data["."].get(k)}' for k in check['promqls'].keys()]))
        yield instance, check_state, ', '.join(check_msgs)
    if has_instance:
        for hostname in get_instances().values():
            if hostname not in checked_instances:
                yield hostname, 'critical', f'{check["title"]}, instance is missing from metrics'


# data is a list of lists, where each list is either:
# Service Check: <host_name>, <svc_description>, <return_code>, <plugin_output>
# Host Check: <host_name>, <return_code>, <plugin_output>
def send_nsca(data):
    input_lines = []
    for line in data:
        assert len(line) in [3,4], f'invalid nsca line: {line}'
        input_lines.append("\t".join([str(item).replace("\t", " ").replace("\n", " ") for item in line]))
    p = subprocess.run(
        [SEND_NSCA_BINARY, "-c", SEND_NSCA_CONFIG, "-H", SEND_NSCA_HOST],
        input="\n".join(input_lines) + "\n",
        text=True, stdout=subprocess.PIPE
    )
    assert p.returncode == 0, f'send_nsca failed with exit code {p.returncode}\n{p.stdout}'
    assert p.stdout.strip().startswith(f'{len(input_lines)} data packet(s) sent to host successfully.'), f'unexpected send_nsca output: {p.stdout}'
    print(p.stdout.strip())


def get_nsca_returncode(state):
    return {
        None: 0,
        'warning': 1,
        'critical': 2,
    }[state]


def check_all_send(config):
    for check_id in config['checks']:
        print(f'checking {check_id}...')
        nsca_data = []
        for hostname, state, msg in get_check_states(config, check_id):
            nsca_data.append([
                hostname, f'cwmc-{check_id}', get_nsca_returncode(state), msg
            ])
        send_nsca(nsca_data)


def daemon_iteration(config, state):
    if state['last_check'] is None or time.time() - state['last_check'] > DAEMON_ITERATIONS_TTL:
        state['last_check'] = time.time()
        print(datetime.datetime.now().isoformat(), 'Starting checks...')
        state['in_progress'] = True
        check_all_send(config)
        state['in_progress'] = False
        print(datetime.datetime.now().isoformat(), 'Done checks')


def daemon(config):
    state = {
        'terminate': False,
        'in_progress': False,
        'last_check': None,
    }

    def handle_terminate(*args):
        if state['in_progress']:
            print('Received termination signal, waiting for in progress iteration to finish...')
            state['terminate'] = True
        else:
            print('Received termination signal, no in progress iteration, exiting...')
            exit(0)

    signal.signal(signal.SIGTERM, handle_terminate)
    signal.signal(signal.SIGINT, handle_terminate)
    while not state['terminate']:
        daemon_iteration(config, state)
        time.sleep(1)


def main(*args):
    if len(args) > 1 and args[1].endswith('.yaml'):
        with open(args[1]) as f:
            config = safe_load(f)
        res = globals()[args[0]](config, *args[2:])
    else:
        res = globals()[args[0]](*args[1:])
    if isinstance(res, types.GeneratorType):
        print('[')
        for i, o in enumerate(res):
            if i > 0:
                print(',')
            print(json.dumps(o, indent=2))
        print(']')
    else:
        print(json.dumps(res, indent=2))


if __name__ == '__main__':
    main(*sys.argv[1:])
