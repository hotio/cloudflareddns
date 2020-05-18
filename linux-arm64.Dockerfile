FROM hotio/base@sha256:b7f9f793ba275ea953ce4979b7a7c86e35ec3c2a93ca5932d0e0845ede0b3367

ARG DEBIAN_FRONTEND="noninteractive"

ENV INTERVAL=300 DETECTION_MODE="dig-whoami.cloudflare" LOG_LEVEL=3 CHECK_IPV4="true" CHECK_IPV6="false"

ARG APPRISE_VERSION

# install packages
RUN apt update && \
    apt install -y --no-install-recommends --no-install-suggests \
        dnsutils \
        python3-pip python3-setuptools && \
    pip3 install --no-cache-dir --upgrade apprise==${APPRISE_VERSION} && \
# clean up
    apt purge -y python3-pip python3-setuptools && \
    apt autoremove -y && \
    apt clean && \
    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

COPY root/ /

RUN chmod 755 "${APP_DIR}/cloudflare-ddns.sh"