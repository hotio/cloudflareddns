# cloudflare-ddns

[![GitHub](https://img.shields.io/badge/source-github-lightgrey?style=flat-square)](https://github.com/hotio/docker-cloudflare-ddns)
[![Docker Pulls](https://img.shields.io/docker/pulls/hotio/cloudflare-ddns?style=flat-square)](https://hub.docker.com/r/hotio/cloudflare-ddns)
[![Drone (cloud)](https://img.shields.io/drone/build/hotio/docker-cloudflare-ddns?style=flat-square)](https://cloud.drone.io/hotio/docker-cloudflare-ddns)

## Starting the container

Just the basics to get the container running:

```shell
docker run --rm --name cloudflare-ddns -e TZ=Etc/UTC hotio/cloudflare-ddns
```

The environment variables below are all optional, the values you see are the defaults.

```shell
-e PUID=1000
-e PGID=1000
-e UMASK=022
-e INTERVAL=300
-e DETECTION_MODE="dig-google.com"
-e LOG_LEVEL=2
```

Possible values for `DETECTION_MODE` are `dig-google.com`, `dig-opendns.com`, `curl-icanhazip.com`, `curl-wtfismyip.com`, `curl-showmyip.ca`, `curl-da.gd` and `curl-seeip.org`. For `LOG_LEVEL` you can pick `0` to disable logging, `1` to log only errors or actual updates and `2` to also log when nothing has changed.

The following environment variables are used to configure the domains you would like to update.

```shell
-e CF_USER="your.cf.email@example.com"
-e CF_APIKEY="yourcfapikey"
-e CF_ZONES="example.com;foobar.com;foobar.com"
-e CF_HOSTS="test.example.com;test.foobar.com;test2.foobar.com"
-e CF_RECORDTYPES="A;A;AAAA"
```

Notice that we give 3 values each time for `CF_ZONES`, `CF_HOSTS` and `CF_RECORDTYPES`. In our example, the domain `test.foobar.com` belonging to the zone `foobar.com` will have its A record updated with an ipv4 ip.

## Tags

| Tag      | Description                    |
| ---------|--------------------------------|
| latest   | The same as `stable`           |
| stable   | Stable version                 |

You can also find tags that reference a commit or version number.

## Example of the log output

```text
2019-08-11 11:42:01 - [dig-google.com] - [test.example.com] - [A] - Updating IP [1.1.1.1] to [1.1.1.1]: NO CHANGE
2019-08-11 11:43:01 - [dig-google.com] - [test.foobar.com] - [A] - Updating IP [8.8.8.8] to [1.1.1.1]: OK
2019-08-11 11:43:01 - [dig-google.com] - [test2.foobar.com] - [AAAA] - Updating IP [2606:4700:4700::1111] to [2606:4700:4700::1111]: NO CHANGE
```

## Cached results from Cloudflare

The returned results from Cloudflare are cached in memory (`/dev/shm`). This means minimal api calls to Cloudflare. If you have made any manual changes to the IP on the Cloudflare webinterface, for instance when wanting to test an update, a container restart is needed to clear the cache.

The proxy setting (orange cloud) is also cached and re-set based on the previous value, so if you made modifications to this setting, you should restart the container so that the script is aware of the new setting.

## InfluxDB Logging

You can enable logging of the new ip to InfluxDB by setting `INFLUXDB_ENABLED` to `true`, below are the defaults. When a succesful update has been done to Cloudflare, the new ip will be logged.

```shell
-e INFLUXDB_ENABLED="false"
-e INFLUXDB_HOST="http://127.0.0.1:8086"
-e INFLUXDB_DB="cloudflare_ddns"
-e INFLUXDB_USER=""
-e INFLUXDB_PASS=""
```

It is also recommended that you add `--hostname YOUR_CONTAINER_HOSTNAME` to your docker command, otherwise the hostname that is logged to InfluxDB will change on every container update.

You can also import the grafana dashboard pictured below by copying and pasting the json ([Link to Grafana Dasboard JSON](https://raw.githubusercontent.com/hotio/docker-cloudflare-ddns/master/grafana/Cloudflare%20DDNS-1565783977844.json)). By default only the last entry is shown, but you can show all entries by removing `LIMIT 1` on the Query settings page.

![grafana_panel](https://raw.githubusercontent.com/hotio/docker-cloudflare-ddns/master/grafana/grafana.png "Grafana Dashboard Panel")

Information about the domain updates can be found in `domains`. There's also connection status available for both ipv4 and ipv6 in `connection`.
