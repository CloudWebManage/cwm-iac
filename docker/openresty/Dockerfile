FROM openresty/openresty:1.21.4.1-0-alpine@sha256:42475b68d2f3270307d4359b39083eb6b514edb2b816970d990f585579929f00

RUN apk update && apk add --no-cache --no-cache ca-certificates curl bash python3 perl
RUN opm get knyar/nginx-lua-prometheus=0.20240525 &&\
    rm -rf /root/.opm &&\
    HASH_VALIDATION="2df9ca4b2d547e51bb2477edcaac68c8bb0f0ea18719b811abdac6bde69bfc1d" &&\
    HASH="$(find /usr/local/openresty/ -type f -print | sort | xargs sha256sum | sha256sum | cut -d' ' -f1)" &&\
    if [ "${HASH}" != "${HASH_VALIDATION}" ]; then \
      echo "Failed hash validation: ${HASH}"; exit 1; \
    fi

COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
