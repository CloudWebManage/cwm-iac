import os
import re


def conf_replace(content, pattern, key):
    replacement = os.getenv(key)
    if replacement:
        content, count = re.subn(
            pattern,
            lambda m: m.group(1) + replacement + m.group(2),
            content
        )
        assert count == 1, f"Pattern '{pattern}' found {count} times in config"
    return content


def conf_replace_file(file, patterns):
    with open(file) as f:
        content = f.read()
    for key, pattern in patterns:
        content = conf_replace(content, pattern, key)
    with open(file, "w") as f:
        f.write(content)


def main(etc_nginx_path="/etc/nginx", url_local_openresty_nginx_path="/usr/local/openresty/nginx"):
    conf_replace_file(f"{url_local_openresty_nginx_path}/conf/nginx.conf", [
        ('WORKER_CONNECTIONS', r'(worker_connections  )1024(;)'),
        ('WORKER_PROCESSES', r'(worker_processes )2(;)'),
        ('ERROR_LOG_LEVEL', r'(error_log  stderr  )error(;)'),
    ])
    conf_replace_file(f"{etc_nginx_path}/metrics.conf", [
        ('METRICS_LUA_SHARED_DICT_SIZE', r'(lua_shared_dict prometheus_metrics )16m(;)'),
    ])
    conf_replace_file(f"{etc_nginx_path}/metrics_server.conf", [
        ('METRICS_SERVER_PORT', r'(listen )9999(;)'),
    ])


if __name__ == "__main__":
    main()
