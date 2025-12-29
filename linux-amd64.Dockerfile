ARG UPSTREAM_IMAGE
ARG UPSTREAM_DIGEST_AMD64

FROM ${UPSTREAM_IMAGE}@${UPSTREAM_DIGEST_AMD64}
ARG IMAGE_STATS
ENV IMAGE_STATS=${IMAGE_STATS} INTERVAL=300 DETECTION_MODE="dig-whoami.cloudflare" LOG_LEVEL=3

ARG APPRISE_VERSION
RUN apk add --no-cache python3 py3-six py3-requests py3-pip py3-cryptography ncurses iproute2 bind-tools && \
    pip3 install --break-system-packages --no-cache-dir --upgrade apprise==${APPRISE_VERSION} && \
    apk del --purge py3-pip

COPY root/ /

RUN chmod 755 "${APP_DIR}/cloudflare-ddns.sh" && \
    find /etc/s6-overlay/s6-rc.d -name "run*" -execdir chmod +x {} +
