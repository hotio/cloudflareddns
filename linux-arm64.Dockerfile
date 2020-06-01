FROM hotio/base@sha256:ee9c3c7f7c71b22c022b4e3b8835a4f61444f951490b2f40db716c79f7d37349

ARG DEBIAN_FRONTEND="noninteractive"

ENV INTERVAL=300 DETECTION_MODE="dig-whoami.cloudflare" LOG_LEVEL=3

ARG APPRISE_VERSION

# install packages
RUN apk add --no-cache iproute2 bind-tools python3 py3-pip && \
    pip3 install --no-cache-dir --upgrade apprise==${APPRISE_VERSION} && \
    apk del --purge py3-pip

COPY root/ /

RUN chmod 755 "${APP_DIR}/cloudflare-ddns.sh"
