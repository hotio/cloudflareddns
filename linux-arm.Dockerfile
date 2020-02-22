FROM hotio/base@sha256:8598d7707dd3e8471cf80df6a471a1f100f207ca5f1e33b08e6b0a64d961e3dd

ARG DEBIAN_FRONTEND="noninteractive"

ENV INTERVAL=300 DETECTION_MODE="dig-google.com" LOG_LEVEL=2 INFLUXDB_ENABLED="false" INFLUXDB_HOST="http://127.0.0.1:8086" INFLUXDB_DB="cloudflare_ddns" INFLUXDB_USER="" INFLUXDB_PASS=""

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
