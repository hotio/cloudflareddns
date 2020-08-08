FROM hotio/base@sha256:c0d26bf85d89f03b93cdb5d0882e4f1573ca1a30d9f6d059c1ad06ccb568c6a9

ENV INTERVAL=300 DETECTION_MODE="dig-whoami.cloudflare" LOG_LEVEL=3

ARG APPRISE_VERSION
RUN apk add --no-cache python3 py3-six py3-requests py3-pip ncurses iproute2 bind-tools && \
    pip3 install --no-cache-dir --upgrade apprise==${APPRISE_VERSION} && \
    apk del --purge py3-pip

COPY root/ /

RUN chmod 755 "${APP_DIR}/cloudflare-ddns.sh"
