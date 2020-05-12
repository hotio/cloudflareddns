FROM hotio/base@sha256:0c08ec65409a84cc6cc0110faf6cb6fdd1bcfbe1620d029189b34300f7bdf3ae

ARG DEBIAN_FRONTEND="noninteractive"

ENV INTERVAL=300 DETECTION_MODE="dig-whoami.cloudflare" LOG_LEVEL=3 INFLUXDB_ENABLED="false" INFLUXDB_HOST="http://127.0.0.1:8086" INFLUXDB_DB="cloudflare_ddns" INFLUXDB_USER="" INFLUXDB_PASS="" CHECK_IPV4="true" CHECK_IPV6="false"

# install packages
RUN apt update && \
    apt install -y --no-install-recommends --no-install-suggests \
        dnsutils && \
# clean up
    apt autoremove -y && \
    apt clean && \
    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

COPY root/ /

RUN chmod 755 "${APP_DIR}/cloudflare-ddns.sh"
