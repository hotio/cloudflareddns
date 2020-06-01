FROM hotio/alpine@sha256:238742e903408c88dc230267ebf143391635f2e416d76264ea0c443bff67cf72

ARG DEBIAN_FRONTEND="noninteractive"

ENV INTERVAL=300 DETECTION_MODE="dig-whoami.cloudflare" LOG_LEVEL=3

ARG APPRISE_VERSION

# install packages
RUN apk add --no-cache iproute2 bind-tools python3 py3-pip && \
    pip3 install --no-cache-dir --upgrade apprise==${APPRISE_VERSION} && \
    apk del --purge py3-pip

COPY root/ /

RUN chmod 755 "${APP_DIR}/cloudflare-ddns.sh"
