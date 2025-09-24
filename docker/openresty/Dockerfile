FROM openresty/openresty:1.21.4.1-0-alpine@sha256:42475b68d2f3270307d4359b39083eb6b514edb2b816970d990f585579929f00

RUN apk update && apk add --no-cache --no-cache ca-certificates curl bash python3 perl
RUN opm get knyar/nginx-lua-prometheus=0.20240525 && rm -rf /root/.opm

COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf
COPY entrypoint.sh /entrypoint.sh
COPY metrics.conf /etc/nginx/metrics.conf
COPY metrics_server.conf /etc/nginx/metrics_server.conf

ENTRYPOINT ["/entrypoint.sh"]
