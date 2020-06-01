FROM hotio/base@sha256:83af03120b136d8526a23b38307cdbbb0706feb00048b23a33316477a85d6011

ARG DEBIAN_FRONTEND="noninteractive"

ENV INTERVAL=300 DETECTION_MODE="dig-whoami.cloudflare" LOG_LEVEL=3

ARG APPRISE_VERSION

# install packages
RUN apk add --no-cache iproute2 bind-tools python3 py3-pip && \
    pip3 install --no-cache-dir --upgrade apprise==${APPRISE_VERSION} && \
    apk del --purge py3-pip

COPY root/ /

RUN chmod 755 "${APP_DIR}/cloudflare-ddns.sh"
