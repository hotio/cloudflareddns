# Cloudflare DDNS

[![badge](https://images.microbadger.com/badges/image/hotio/cloudflare-ddns.svg)](https://microbadger.com/images/hotio/cloudflare-ddns "Get your own image badge on microbadger.com")
[![badge](https://images.microbadger.com/badges/version/hotio/cloudflare-ddns.svg)](https://microbadger.com/images/hotio/cloudflare-ddns "Get your own version badge on microbadger.com")
[![badge](https://images.microbadger.com/badges/commit/hotio/cloudflare-ddns.svg)](https://microbadger.com/images/hotio/cloudflare-ddns "Get your own commit badge on microbadger.com")

## Donations

NANO: `xrb_1bxqm6nsm55s64rgf8f5k9m795hda535to6y15ik496goatakpupjfqzokfc`  
BTC: `39W6dcaG3uuF5mZTRL4h6Ghem74kUBHrmz`  
LTC: `MMUFcGLiK6DnnHGFnN2MJLyTfANXw57bDY`

## Starting the container

Just the basics to get the container running:

```shell
docker run --rm --name cloudflare-ddns -v /tmp/cloudflare-ddns:/config -e TZ=Etc/UTC hotio/cloudflare-ddns
```

The environment variables `PUID`, `PGID`, `UMASK`, `CRON_TIME` and `DETECTION_MODE` are all optional, the values you see below are the default values.

```shell
-e PUID=1000
-e PGID=1000
-e UMASK=022
-e CRON_TIME="*/5 * * * *"
-e DETECTION_MODE="dig-google"
```

Possible values for `DETECTION_MODE` are `dig-google` and `curl-icanhazip`.

The following environment variables are used to configure the domains you would like to update.

```shell
-e CF_USER="<your cf email>"
-e CF_APIKEY="<your cf apikey>"
-e CF_ZONES="example.com;foobar.com;foobar.com"
-e CF_HOSTS="test.example.com;test.foobar.com;test2.foobar.com"
-e CF_RECORDTYPES="A;A;AAAA"
```

Notice that we give 3 values each time for `CF_ZONES`, `CF_HOSTS` and `CF_RECORDTYPES`. In our example, the domain `test.foobar.com` belonging to the zone `foobar.com` will have its A record updated with an ipv4 ip.

## Example of the log output

```text
2019-08-11 11:42:01 - [dig-google] - [test.example.com] - [A] - Updating IP [1.1.1.1] to [1.1.1.1]: NO CHANGE
2019-08-11 11:43:01 - [dig-google] - [test.foobar.com] - [A] - Updating IP [8.8.8.8] to [1.1.1.1]: OK
2019-08-11 11:43:01 - [dig-google] - [test2.foobar.com] - [AAAA] - Updating IP [2606:4700:4700::1111] to [2606:4700:4700::1111]: NO CHANGE
```

## Cached results from Cloudflare

The returned results from Cloudflare are cached in memory (`/dev/shm`). This means minimal api calls to Cloudflare. If you have made any manual changes to the IP on the Cloudflare webinterface, for instance when wanting to test an update, a container restart is needed to clear the cache.

The proxy setting (orange cloud) is also cached and re-set based on the previous value, so if you made modifications to this setting, you should restart the container so that the script is aware of the new setting.
