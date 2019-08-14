FROM hotio/base

ARG DEBIAN_FRONTEND="noninteractive"

ENV APP="Cloudflare DDNS" CRON_TIME="*/5 * * * *" DETECTION_MODE="dig-google.com" LOG_LEVEL=2 INFLUXDB_ENABLED="false" INFLUXDB_HOST="http://127.0.0.1:8086" INFLUXDB_DB="cloudflare_ddns" INFLUXDB_USER="" INFLUXDB_PASS=""
HEALTHCHECK --interval=60s CMD pidof cron || exit 1

# install packages
RUN apt update && \
    apt install -y --no-install-recommends --no-install-suggests \
        cron dnsutils && \
# clean up
    apt autoremove -y && \
    apt clean && \
    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* /etc/cont-init.d/*

COPY root/ /
