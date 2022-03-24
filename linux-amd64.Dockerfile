FROM cr.hotio.dev/hotio/base@sha256:8935fb7523e5f13f27b10500d3bb9eceb105d44c8b521b585e8994dc898ddb51

ENV INTERVAL=300 DETECTION_MODE="dig-whoami.cloudflare" LOG_LEVEL=3

ARG APPRISE_VERSION
RUN apk add --no-cache python3 py3-six py3-requests py3-pip py3-cryptography ncurses iproute2 bind-tools && \
    pip3 install --no-cache-dir --upgrade apprise==${APPRISE_VERSION} && \
    apk del --purge py3-pip

COPY root/ /

RUN chmod 755 "${APP_DIR}/cloudflare-ddns.sh"
