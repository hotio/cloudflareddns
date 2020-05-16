# cloudflare-ddns

<img src="https://raw.githubusercontent.com/hotio/unraid-templates/master/hotio/img/cloudflare-ddns.png" alt="Logo" height="130" width="130">

[![GitHub](https://img.shields.io/badge/source-github-lightgrey)](https://github.com/hotio/docker-cloudflare-ddns)
[![Docker Pulls](https://img.shields.io/docker/pulls/hotio/cloudflare-ddns)](https://hub.docker.com/r/hotio/cloudflare-ddns)
[![Discord](https://img.shields.io/discord/610068305893523457?color=738ad6&label=discord&logo=discord&logoColor=white)](https://discord.gg/3SnkuKp)

## Starting the container

Just the basics to get the container running:

```shell
docker run --rm --name cloudflare-ddns -v /<host_folder_config>:/config hotio/cloudflare-ddns
```

The environment variables below are all optional, the values you see are the defaults.

```shell
-e PUID=1000
-e PGID=1000
-e UMASK=002
-e TZ="Etc/UTC"
-e ARGS=""
-e INTERVAL=300
-e DETECTION_MODE="dig-whoami.cloudflare"
-e LOG_LEVEL=3
-e CHECK_IPV4="true"
-e CHECK_IPV6="false"
```

Possible values for `DETECTION_MODE` are `dig-google.com`, `dig-opendns.com`, `dig-whoami.cloudflare`, `curl-icanhazip.com`, `curl-wtfismyip.com`, `curl-showmyip.ca`, `curl-da.gd`, `curl-seeip.org` and `curl-ifconfig.co`. For `LOG_LEVEL` you can pick `0` to disable logging, `1` to log only errors or actual updates, `2` to also log when nothing has changed, `3` to get debug logging and `4` to get very verbose debug logs.

The following environment variables are used to configure the domains you would like to update.

```shell
-e CF_USER="your.cf.email@example.com"
-e CF_APIKEY="your.global.apikey"
-e CF_APITOKEN=""
-e CF_APITOKEN_ZONE=""
-e CF_HOSTS="test.example.com;test.foobar.com;test2.foobar.com"
-e CF_ZONES="example.com;foobar.com;foobar.com"
-e CF_RECORDTYPES="A;A;AAAA"
```

Notice that we give 3 values each time for `CF_HOSTS`, `CF_ZONES` and `CF_RECORDTYPES`. In our example, the domain `test.foobar.com` belonging to the zone `foobar.com` will have its A record updated with an ipv4 ip. If you use `CF_APITOKEN`, you can leave `CF_USER` and `CF_APIKEY` empty.

> IMPORTANT: All the domain names in `CF_HOSTS` should have properly configured DNS records on Cloudflare, they will not be created.

## Tags

| Tag      | Description          | Build Status                                                                                                                                                            | Last Updated                                                                                                                                                                    |
| ---------|----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| latest   | The same as `stable` |                                                                                                                                                                         |                                                                                                                                                                                 |
| stable   | Stable version       | [![Build Status](https://cloud.drone.io/api/badges/hotio/docker-cloudflare-ddns/status.svg?ref=refs/heads/stable)](https://cloud.drone.io/hotio/docker-cloudflare-ddns) | [![GitHub last commit (branch)](https://img.shields.io/github/last-commit/hotio/docker-cloudflare-ddns/stable)](https://github.com/hotio/docker-cloudflare-ddns/commits/stable) |

You can also find tags that reference a commit or version number.

## Zone ID

Instead of the `zone_name`, you can also fill in a `zone_id` in `CF_ZONES`. When using a `zone_id`, you can use a scoped token (`CF_APITOKEN`) that only needs the `Zone - DNS - Edit` permissions. This improves security. The configuration could look like the example below.

```shell
-e CF_APITOKEN="azkqvJ86wEScojvSJC8DyY67TwqNwZCtomEVrHwt"
-e CF_HOSTS="example.com;test.foobar.com"
-e CF_ZONES="zbpsi9ceikrdnnym27s2xnp6s5dvj6ep;dccbe6grakumohwwd4amh4o46yupepn8"
-e CF_RECORDTYPES="A;A"
```

## Seperate API Tokens

If you do not prefer to use a `zone_id`, but prefer some more security, you can use 2 seperate tokens.

`CF_APITOKEN` configured with:

**Permissions**  
`Zone - DNS - Edit`  
**Zone Resources**  
`Include - Specific zone - example.com`  
`Include - Specific zone - foobar.com`

`CF_APITOKEN_ZONE` configured with:

**Permissions**  
`Zone - Zone - Read`  
**Zone Resources**  
`Include - All zones`

Leaving `CF_APITOKEN_ZONE` blank would mean that only `CF_APITOKEN` will be used and thus that token should have all required permissions. Which usually means that the token could edit all zones or not be able to fetch the `zone_id` from the `zone_name`.

## Configuration combination examples

Below are some example configuration combinations, ordered from most secure to least secure.

* We use a `zone_id` so that our token only needs the permissions `Zone - DNS - Edit`.

```shell
-e CF_APITOKEN="azkqvJ86wEScojvSJC8DyY67TwqNwZCtomEVrHwt"
-e CF_HOSTS="vpn.example.com;test.foobar.com"
-e CF_ZONES="zbpsi9ceikrdnnym27s2xnp6s5dvj6ep;axozor886pyja7nmbcvu5kh7dp9557j4"
-e CF_RECORDTYPES="A;A"
```

* We use additionally a `CF_APITOKEN_ZONE` with the permissions `Zone - Zone - Read` to query the zones and getting the `zone_id`.

```shell
-e CF_APITOKEN="azkqvJ86wEScojvSJC8DyY67TwqNwZCtomEVrHwt"
-e CF_APITOKEN_ZONE="8m4TxzWb9QHXEpTwQDMugkKuHRavsxoK8qmJ4P7M"
-e CF_HOSTS="vpn.example.com;test.foobar.com"
-e CF_ZONES="example.com;axozor886pyja7nmbcvu5kh7dp9557j4"
-e CF_RECORDTYPES="A;A"
```

* We use only `CF_APITOKEN`, but with the permissions `Zone - DNS - Edit` and `Zone - Zone - Read`.

```shell
-e CF_APITOKEN="azkqvJ86wEScojvSJC8DyY67TwqNwZCtomEVrHwt"
-e CF_HOSTS="vpn.example.com;test.foobar.com"
-e CF_ZONES="example.com;axozor886pyja7nmbcvu5kh7dp9557j4"
-e CF_RECORDTYPES="A;A"
```

* We use `CF_USER` and `CF_APIKEY`, basically giving full control over our account.

```shell
-e CF_USER="your.cf.email@example.com"
-e CF_APIKEY="your.global.apikey"
-e CF_HOSTS="vpn.example.com;test.foobar.com"
-e CF_ZONES="example.com;axozor886pyja7nmbcvu5kh7dp9557j4"
-e CF_RECORDTYPES="A;A"
```

## Example of the log output

```text
2020-05-15 19:23:48 - Attempting to find IP...
2020-05-15 19:23:48 - IPv4 detected by [dig-whoami.cloudflare] is [1.1.1.1]
2020-05-15 19:23:48 - IPv6 detected by [dig-whoami.cloudflare] is [disabled]
2020-05-15 19:23:48 - [1/2] [vpn.example.com - A] Reading zone list from Cloudflare
2020-05-15 19:23:48 - [1/2] [vpn.example.com - A] Contacting [https://api.cloudflare.com/client/v4/zones], using [CF_USER=your.email@gmail.com & CF_APIKEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx] to authenticate...
2020-05-15 19:23:49 - [1/2] [vpn.example.com - A] Retrieved zone list from Cloudflare
2020-05-15 19:23:49 - [1/2] [vpn.example.com - A] Zone ID returned by Cloudflare for zone [example.com] is: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
2020-05-15 19:23:49 - [1/2] [vpn.example.com - A] Reading DNS records from Cloudflare
2020-05-15 19:23:49 - [1/2] [vpn.example.com - A] Contacting [https://api.cloudflare.com/client/v4/zones/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/dns_records], using [CF_USER=your.email@gmail.com & CF_APIKEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx] to authenticate...
2020-05-15 19:23:49 - [1/2] [vpn.example.com - A] Wrote DNS records to cache file: /config/app/cf-ddns-vpn.example.com-A.cache
2020-05-15 19:23:49 - [1/2] [vpn.example.com - A] Updating IP [1.1.1.1] to [1.1.1.1]: NO CHANGE
2020-05-15 19:23:49 - [2/2] [test.example.com - A] No value was found in [CF_ZONES] for host [test.example.com], the previous value [example.com] is used instead.
2020-05-15 19:23:49 - [2/2] [test.example.com - A] Reading zone list from Cloudflare
2020-05-15 19:23:50 - [2/2] [test.example.com - A] Contacting [https://api.cloudflare.com/client/v4/zones], using [CF_USER=your.email@gmail.com & CF_APIKEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx] to authenticate...
2020-05-15 19:23:50 - [2/2] [test.example.com - A] Retrieved zone list from Cloudflare
2020-05-15 19:23:50 - [2/2] [test.example.com - A] Zone ID returned by Cloudflare for zone [example.com] is: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
2020-05-15 19:23:50 - [2/2] [test.example.com - A] Reading DNS records from Cloudflare
2020-05-15 19:23:50 - [2/2] [test.example.com - A] Contacting [https://api.cloudflare.com/client/v4/zones/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/dns_records], using [CF_USER=your.email@gmail.com & CF_APIKEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx] to authenticate...
2020-05-15 19:23:50 - [2/2] [test.example.com - A] Something went wrong trying to find [test.example.com - A] in the DNS records returned by Cloudflare!
2020-05-15 19:23:50 - Going to sleep for 300 seconds...
```

## Cached results from Cloudflare

The returned results from Cloudflare are cached. This means minimal api calls to Cloudflare. If you have made any manual changes to the IP on the Cloudflare webinterface, for instance when wanting to test an update, a container restart is needed to clear the cache.

The proxy setting (orange cloud) and TTL is also cached and re-set based on the previous value, so if you made any modifications to these settings, you should restart the container so that the script is aware of the new settings.

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

Information about the domain updates can be found in `domains`.

## Sending notifications using Apprise

You can send notifications when a DNS record gets updated with a new IP using [Apprise](https://github.com/caronc/apprise/blob/master/README.md). Use the environment variable `APPRISE` to configure notifications, see below for some examples.

```shell
-e APPRISE="pover://user@token"
-e APPRISE="pover://user@token;discord://webhook_id/webhook_token"
```
