FROM openresty/openresty:1.31.8.1-0-alpine@sha256:fec9da11e7a975d67caf66aaf70e9af2a101fdb167e0b60502c94a4e4959b943

RUN apk add --no-cache ca-certificates curl bash python3 perl

# The tagged release is available upstream while its OPM publication is pending.
ADD --checksum=sha256:c2f42db365feaab20206465b06cd3b700f1157336c10ecc55675c04577dcc911 https://codeload.github.com/knyar/nginx-lua-prometheus/tar.gz/refs/tags/0.20260912 /tmp/nginx-lua-prometheus.tar.gz
RUN tar -xzf /tmp/nginx-lua-prometheus.tar.gz -C /tmp && \
    cd /tmp/nginx-lua-prometheus-0.20260912 && \
    cp prometheus.lua prometheus_keys.lua prometheus_resty_counter.lua /usr/local/openresty/site/lualib/ && \
    mkdir -p /usr/local/share/licenses/nginx-lua-prometheus && \
    cp LICENSE /usr/local/share/licenses/nginx-lua-prometheus/ && \
    rm -rf /tmp/nginx-lua-prometheus*

COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf
COPY entrypoint.sh /entrypoint.sh
COPY metrics.conf /etc/nginx/metrics.conf
COPY metrics_shared_dict.conf /etc/nginx/metrics_shared_dict.conf
COPY metrics_init.lua /etc/nginx/metrics_init.lua
COPY metrics_log.lua /etc/nginx/metrics_log.lua
COPY metrics_server.conf /etc/nginx/metrics_server.conf
COPY entrypoint.py /docker-entrypoint.d/000-openresty-entrypoint.py

ENTRYPOINT ["/entrypoint.sh"]
