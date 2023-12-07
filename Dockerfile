ARG UPSTREAM_VERSION=1.21.4.1-0-alpine
FROM openresty/openresty:${UPSTREAM_VERSION}

RUN \
    apk add --no-cache \
      python3 \
      ;

COPY /rootfs /
