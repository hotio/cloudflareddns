FROM hotio/base@sha256:dba94df91a2c476ec1e3717a2f76fd01ef5b9fcf1a1baa0efbac5e3c5b5f77d4

ENV INTERVAL=300 DETECTION_MODE="dig-whoami.cloudflare" LOG_LEVEL=3

ARG APPRISE_VERSION

# install packages
RUN apk add --no-cache ncurses iproute2 bind-tools python3 py3-pip && \
    pip3 install --no-cache-dir --upgrade six apprise==${APPRISE_VERSION} && \
    apk del --purge py3-pip

COPY root/ /

RUN chmod 755 "${APP_DIR}/cloudflare-ddns.sh"
