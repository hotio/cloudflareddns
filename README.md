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

The environment variables `PUID`, `PGID`, `UMASK` and `CRON_TIME` are all optional, the values you see below are the default values.

```shell
-e PUID=1000
-e PGID=1000
-e UMASK=022
-e CRON_TIME="*/5 * * * *"
```

The following environment variables are used to configure the domains you would like to update.

```shell
-e CF_USER="<your cf email>"
-e CF_APIKEY="<your cf apikey>"
-e CF_ZONES="example.com;foobar.com;foobar.com"
-e CF_HOSTS="test.example.com;test.foobar.com;test2.foobar.com"
-e CF_RECORDTYPES="A;A;AAAA"
-e MODES="4;4;6"
```

Notice that we give 3 values each time for `CF_ZONES`, `CF_HOSTS`, `CF_RECORDTYPES` and `MODES`. In our example, the domain `test.foobar.com` belonging to the zone `foobar.com` will have its A record updated with an ipv4 ip. The `MODES` variable can have the values `4` or `6`, depending on if you want to update a record with an ipv4 or ipv6 ip.
