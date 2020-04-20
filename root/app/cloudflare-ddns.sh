#!/usr/bin/with-contenv bash
# shellcheck shell=bash

echo $$ > /dev/shm/cloudflare-ddns.pid

###################################
## CREATE INFLUXDB DB IF ENABLED ##
###################################

if [[ ${INFLUXDB_ENABLED} == "true" ]]; then
    if result=$(curl -fsSL -XPOST "${INFLUXDB_HOST}/query" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-urlencode "q=SHOW DATABASES"); then
        [[ ${LOG_LEVEL} -gt 0 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - Connection to \"${INFLUXDB_HOST}\" succeeded!"
        if echo "${result}" | jq -erc ".results[].series[].values[] | select(. == [\"${INFLUXDB_DB}\"])" > /dev/null; then
            [[ ${LOG_LEVEL} -gt 0 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - Database \"${INFLUXDB_DB}\" found!"
        else
            [[ ${LOG_LEVEL} -gt 0 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - Database \"${INFLUXDB_DB}\" not found! Creating database..."
            curl -fsSL -XPOST "${INFLUXDB_HOST}/query" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-urlencode "q=CREATE DATABASE ${INFLUXDB_DB}" > /dev/null
            [[ ${LOG_LEVEL} -gt 0 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - Adding sample data..."
            curl -fsSL -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "domains,host=sample-generator,domain=ipv4.cloudflare.com,recordtype=A ip=\"1.1.1.1\""
            curl -fsSL -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "domains,host=sample-generator,domain=ipv6.cloudflare.com,recordtype=AAAA ip=\"2606:4700:4700::1111\""
        fi
    fi
fi

###################
## CONFIGURATION ##
###################

cfuser="${CF_USER}"
cfapikey="${CF_APIKEY}"
cfapitoken="${CF_APITOKEN}"
cfapitokenzone="${CF_APITOKEN_ZONE}"

DEFAULTIFS="${IFS}"
IFS=';'
read -r -a cfzone <<< "${CF_ZONES}"
read -r -a cfhost <<< "${CF_HOSTS}"
read -r -a cftype <<< "${CF_RECORDTYPES}"
IFS="${DEFAULTIFS}"

regexv4='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
regexv6='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'

#################
## UPDATE LOOP ##
#################

while true; do

    ## CHECK FOR NEW IP ##
    [[ ${LOG_LEVEL} -gt 2 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - Trying to get IP..."
    case "${DETECTION_MODE}" in
        dig-google.com)
            newipv4=$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
            newipv6=$(dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
            ;;
        dig-opendns.com)
            newipv4=$(dig -4 A +short myip.opendns.com @resolver1.opendns.com)
            newipv6=$(dig -6 AAAA +short myip.opendns.com @resolver1.opendns.com)
            ;;
        dig-whoami.cloudflare)
            newipv4=$(dig -4 TXT +short whoami.cloudflare @1.1.1.1 ch | tr -d '"')
            newipv6=$(dig -6 TXT +short whoami.cloudflare @2606:4700:4700::1111 ch | tr -d '"')
            ;;
        curl-icanhazip.com)
            newipv4=$(curl -fsL -4 icanhazip.com)
            newipv6=$(curl -fsL -6 icanhazip.com)
            ;;
        curl-wtfismyip.com)
            newipv4=$(curl -fsL -4 wtfismyip.com/text)
            newipv6=$(curl -fsL -6 wtfismyip.com/text)
            ;;
        curl-showmyip.ca)
            newipv4=$(curl -fsL -4 showmyip.ca/ip.php)
            newipv6=$(curl -fsL -6 showmyip.ca/ip.php)
            ;;
        curl-da.gd)
            newipv4=$(curl -fsL -4 da.gd/ip)
            newipv6=$(curl -fsL -6 da.gd/ip)
            ;;
        curl-seeip.org)
            newipv4=$(curl -fsL -4 ip.seeip.org)
            newipv6=$(curl -fsL -6 ip.seeip.org)
            ;;
        curl-ifconfig.co)
            newipv4=$(curl -fsL -4 ifconfig.co)
            newipv6=$(curl -fsL -6 ifconfig.co)
            ;;
    esac
    [[ ${LOG_LEVEL} -gt 2 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - IPv4 is: $newipv4"
    [[ ${LOG_LEVEL} -gt 2 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - IPv6 is: $newipv6"

    ## LOG CONNECTION STATUS TO INFLUXDB IF ENABLED ##
    if [[ ${INFLUXDB_ENABLED} == "true" ]]; then
        [[ ${LOG_LEVEL} -gt 2 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - Writing connection status to InfluxDB..."
        if [[ $newipv4 =~ $regexv4 ]]; then
            curl -fsSL -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "connection,host=$(hostname),type=ipv4 status=1,ip=\"$newipv4\""
        else
            curl -fsSL -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "connection,host=$(hostname),type=ipv4 status=0,ip=\"no ipv4\""
        fi

        if [[ $newipv6 =~ $regexv6 ]]; then
            curl -fsSL -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "connection,host=$(hostname),type=ipv6 status=1,ip=\"$newipv6\""
        else
            curl -fsSL -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "connection,host=$(hostname),type=ipv6 status=0,ip=\"no ipv6\""
        fi
    fi

    ## UPDATE DOMAINS ##
    for index in ${!cfzone[*]}; do

        cache="/dev/shm/cf-ddns-${cfhost[$index]}-${cftype[$index]}"

        case "${cftype[$index]}" in
            A)
                regex="${regexv4}"
                newip="${newipv4}"
                ;;
            AAAA)
                regex="${regexv6}"
                newip="${newipv6}"
                ;;
        esac

        curl_header() {
            if [[ -n $cfapitokenzone ]] && [[ $* != *dns_records* ]]; then
                curl -fsSL -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer $cfapitokenzone" "$@"
                auth="CF_APITOKEN_ZONE=$cfapitokenzone"
            elif [[ -n $cfapitoken ]]; then
                curl -fsSL -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer $cfapitoken" "$@"
                auth="CF_APITOKEN=$cfapitoken"
            else
                curl -fsSL -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Auth-Email: $cfuser" -H "X-Auth-Key: $cfapikey" "$@"
                auth="CF_USER=$cfuser, CF_APIKEY=$cfapikey"
            fi
            [[ ${LOG_LEVEL} -gt 2 ]] && echo "Used \"$auth\" to authenticate..."
        }

        if ! [[ $newip =~ $regex ]]; then
            [[ ${LOG_LEVEL} -gt 0 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Returned IP by \"${DETECTION_MODE}\" is not valid! Check your connection."
        else
            if [[ ! -f "$cache" ]]; then
                zoneid=""
                dnsrecords=""
                [[ ${LOG_LEVEL} -gt 2 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Trying to get DNS records from \"Cloudflare\"..."
                if [[ ${cfzone[$index]} == *.* ]]; then
                    response=$(curl_header -X GET "https://api.cloudflare.com/client/v4/zones") && \
                    zoneid=$(echo "${response}" | jq -r '.result[] | select (.name == "'"${cfzone[$index]}"'") | .id')
                    [[ ${LOG_LEVEL} -gt 2 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Zone ID returned by \"Cloudflare\" is: $zoneid"
                else
                    zoneid=${cfzone[$index]}
                    [[ ${LOG_LEVEL} -gt 2 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Zone ID supplied by \"CF_ZONES\" is: $zoneid"
                fi
                [[ -n $zoneid ]] && \
                    response=$(curl_header -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records") && \
                    dnsrecords=$(echo "${response}" | jq -r '.result[] | {name, id, zone_id, zone_name, content, type, proxied, ttl} | select (.name == "'"${cfhost[$index]}"'") | select (.type == "'"${cftype[$index]}"'")') && \
                    echo "$dnsrecords" > "$cache" && \
                    [[ ${LOG_LEVEL} -gt 2 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Written DNS records to cache file: $cache"
            else
                [[ ${LOG_LEVEL} -gt 2 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Reading DNS records from cache file: $cache"
                dnsrecords=$(cat "$cache")
            fi
            if [[ -n ${dnsrecords} ]]; then
                zoneid=$(echo "$dnsrecords" | jq -r '.zone_id' | head -1)
                id=$(echo "$dnsrecords" | jq -r '.id' | head -1)
                proxied=$(echo "$dnsrecords" | jq -r '.proxied' | head -1)
                ttl=$(echo "$dnsrecords" | jq -r '.ttl' | head -1)
                ip=$(echo "$dnsrecords" | jq -r '.content' | head -1)
                if ! [[ $ip =~ $regex ]]; then
                    [[ ${LOG_LEVEL} -gt 0 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Returned IP by \"Cloudflare\" is not valid! Check your connection or configuration."
                else
                    if [[ "$ip" != "$newip" ]]; then
                        [[ ${LOG_LEVEL} -gt 2 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Trying to update DNS record..."
                        result=NOK
                        response=$(curl_header -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$id" --data '{"id":"'"$id"'","type":"'"${cftype[$index]}"'","name":"'"${cfhost[$index]}"'","content":"'"$newip"'","ttl":'"$ttl"',"proxied":'"$proxied"'}') && result=OK
                        if [[ ${result} == OK ]]; then
                            [[ ${LOG_LEVEL} -gt 0 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Updating IP [$ip] to [$newip]: OK"
                            [[ ${INFLUXDB_ENABLED} == "true" ]] && curl -fsSL -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "domains,host=$(hostname),domain=${cfhost[$index]},recordtype=${cftype[$index]} ip=\"$newip\"" && \
                            [[ ${LOG_LEVEL} -gt 2 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Written IP update to InfluxDB."
                            rm "$cache"
                        else
                            [[ ${LOG_LEVEL} -gt 0 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Updating IP [$ip] to [$newip]: FAILED"
                        fi
                    else
                        [[ ${LOG_LEVEL} -gt 1 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Updating IP [$ip] to [$newip]: NO CHANGE"
                    fi
                fi
            else
                [[ ${LOG_LEVEL} -gt 0 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Couldn't fetch DNS records from \"Cloudflare\"! Check your connection or configuration."
            fi
        fi

    done

    ## SLEEP ##
    [[ ${LOG_LEVEL} -gt 2 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - Going to sleep for ${INTERVAL} seconds..."
    sleep "${INTERVAL}"

done
