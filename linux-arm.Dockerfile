FROM hotio/base@sha256:2ab084590c123e37e9ceb51698d9a9b77b54ab6f211e165cfe80e9a96f8ab916

ARG DEBIAN_FRONTEND="noninteractive"

ENV INTERVAL=300 DETECTION_MODE="dig-whoami.cloudflare" LOG_LEVEL=3

ARG APPRISE_VERSION

# install packages
RUN apk add --no-cache iproute2 bind-tools python3 py3-pip && \
    pip3 install --no-cache-dir --upgrade apprise==${APPRISE_VERSION} && \
    apk del --purge py3-pip

COPY root/ /

RUN chmod 755 "${APP_DIR}/cloudflare-ddns.sh"
