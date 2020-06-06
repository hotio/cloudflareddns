FROM hotio/base@sha256:ad79f26c53e2c7e1ed36dba0a0686990c503835134c63d9ed5aa7951e1b45c23

ENV INTERVAL=300 DETECTION_MODE="dig-whoami.cloudflare" LOG_LEVEL=3

ARG APPRISE_VERSION

RUN apk add --no-cache python3 py3-pip ncurses iproute2 bind-tools && \
    pip3 install --no-cache-dir --upgrade apprise==${APPRISE_VERSION}

COPY root/ /

RUN chmod 755 "${APP_DIR}/cloudflare-ddns.sh"
