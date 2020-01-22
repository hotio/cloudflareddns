#!/usr/bin/with-contenv bash
# shellcheck shell=bash

echo $$ > /dev/shm/cloudflare-ddns.pid

###################################
## CREATE INFLUXDB DB IF ENABLED ##
###################################

if [[ ${INFLUXDB_ENABLED} == "true" ]]; then
    if result=$(curl -s -XPOST "${INFLUXDB_HOST}/query" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-urlencode "q=SHOW DATABASES"); then
        [[ ${LOG_LEVEL} -gt 0 ]] && echo "Connection to \"${INFLUXDB_HOST}\" succeeded!"
        if echo "${result}" | jq -erc ".results[].series[].values[] | select(. == [\"${INFLUXDB_DB}\"])" > /dev/null; then
            [[ ${LOG_LEVEL} -gt 0 ]] && echo "Database \"${INFLUXDB_DB}\" found!"
        else
            [[ ${LOG_LEVEL} -gt 0 ]] && echo "Database \"${INFLUXDB_DB}\" not found! Creating database..."
            curl -s -XPOST "${INFLUXDB_HOST}/query" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-urlencode "q=CREATE DATABASE ${INFLUXDB_DB}" > /dev/null
            [[ ${LOG_LEVEL} -gt 0 ]] && echo "Adding sample data..."
            curl -s -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "domains,host=sample-generator,domain=ipv4.cloudflare.com,recordtype=A ip=\"1.1.1.1\""
            curl -s -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "domains,host=sample-generator,domain=ipv6.cloudflare.com,recordtype=AAAA ip=\"2606:4700:4700::1111\""
        fi
    fi
fi

###################
## CONFIGURATION ##
###################

cfuser="${CF_USER}"
cfapikey="${CF_APIKEY}"
cfapitoken="${CF_APITOKEN}"

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
    case "${DETECTION_MODE}" in
        dig-google.com)
            newipv4=$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
            newipv6=$(dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
            ;;
        dig-opendns.com)
            newipv4=$(dig -4 A +short myip.opendns.com @resolver1.opendns.com)
            newipv6=$(dig -6 AAAA +short myip.opendns.com @resolver1.opendns.com)
            ;;
        curl-icanhazip.com)
            newipv4=$(curl -s -4 icanhazip.com)
            newipv6=$(curl -s -6 icanhazip.com)
            ;;
        curl-wtfismyip.com)
            newipv4=$(curl -s -4 wtfismyip.com/text)
            newipv6=$(curl -s -6 wtfismyip.com/text)
            ;;
        curl-showmyip.ca)
            newipv4=$(curl -s -4 showmyip.ca/ip.php)
            newipv6=$(curl -s -6 showmyip.ca/ip.php)
            ;;
        curl-da.gd)
            newipv4=$(curl -s -4 da.gd/ip)
            newipv6=$(curl -s -6 da.gd/ip)
            ;;
        curl-seeip.org)
            newipv4=$(curl -s -4 ip.seeip.org)
            newipv6=$(curl -s -6 ip.seeip.org)
            ;;
    esac

    ## LOG CONNECTION STATUS TO INFLUXDB IF ENABLED ##
    if [[ ${INFLUXDB_ENABLED} == "true" ]]; then
        if [[ $newipv4 =~ $regexv4 ]]; then
            curl -s -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "connection,host=$(hostname),type=ipv4 status=1,ip=\"$newipv4\""
        else
            curl -s -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "connection,host=$(hostname),type=ipv4 status=0,ip=\"no ipv4\""
        fi

        if [[ $newipv6 =~ $regexv6 ]]; then
            curl -s -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "connection,host=$(hostname),type=ipv6 status=1,ip=\"$newipv6\""
        else
            curl -s -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "connection,host=$(hostname),type=ipv6 status=0,ip=\"no ipv6\""
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

        if ! [[ $newip =~ $regex ]]; then
            [[ ${LOG_LEVEL} -gt 0 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Returned IP by \"${DETECTION_MODE}\" is not valid! Check your connection."
        else
            if [[ ! -f "$cache" ]]; then
                if [[ -z ${cfapitoken} ]]; then
                    zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" -H "X-Auth-Email: $cfuser" -H "X-Auth-Key: $cfapikey" -H "Content-Type: application/json" | jq -r '.result[] | select (.name == "'"${cfzone[$index]}"'") | .id')
                    dnsrecords=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records" -H "X-Auth-Email: $cfuser" -H "X-Auth-Key: $cfapikey" -H "Content-Type: application/json" | jq -r '.result[] | {name, id, zone_id, zone_name, content, type, proxied} | select (.name == "'"${cfhost[$index]}"'") | select (.type == "'"${cftype[$index]}"'")')
                else
                    zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" -H "Authorization: Bearer $cfapitoken" -H "Content-Type: application/json" | jq -r '.result[] | select (.name == "'"${cfzone[$index]}"'") | .id')
                    dnsrecords=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records" -H "Authorization: Bearer $cfapitoken" -H "Content-Type: application/json" | jq -r '.result[] | {name, id, zone_id, zone_name, content, type, proxied} | select (.name == "'"${cfhost[$index]}"'") | select (.type == "'"${cftype[$index]}"'")')
                fi
                echo "$dnsrecords" > "$cache"
            else
                dnsrecords=$(cat "$cache")
                zoneid=$(echo "$dnsrecords" | jq -r '.zone_id' | head -1)
            fi
            id=$(echo "$dnsrecords" | jq -r '.id' | head -1)
            proxied=$(echo "$dnsrecords" | jq -r '.proxied' | head -1)
            ip=$(echo "$dnsrecords" | jq -r '.content' | head -1)
            if ! [[ $ip =~ $regex ]]; then
                [[ ${LOG_LEVEL} -gt 0 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Returned IP by \"Cloudflare\" is not valid! Check your connection or configuration."
            else
                if [[ "$ip" != "$newip" ]]; then
                    if [[ -z ${cfapitoken} ]]; then
                        response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$id" -H "X-Auth-Email: $cfuser" -H "X-Auth-Key: $cfapikey" -H "Content-Type: application/json" --data '{"id":"'"$id"'","type":"'"${cftype[$index]}"'","name":"'"${cfhost[$index]}"'","content":"'"$newip"'","proxied":'"$proxied"'}' | jq '.success')
                    else
                        response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$id" -H "Authorization: Bearer $cfapitoken" -H "Content-Type: application/json" --data '{"id":"'"$id"'","type":"'"${cftype[$index]}"'","name":"'"${cfhost[$index]}"'","content":"'"$newip"'","proxied":'"$proxied"'}' | jq '.success')
                    fi
                    if [[ ${response} == true ]]; then
                        [[ ${LOG_LEVEL} -gt 0 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Updating IP [$ip] to [$newip]: OK"
                        [[ ${INFLUXDB_ENABLED} == "true" ]] && curl -s -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "domains,host=$(hostname),domain=${cfhost[$index]},recordtype=${cftype[$index]} ip=\"$newip\""
                        rm "$cache"
                    else
                        [[ ${LOG_LEVEL} -gt 0 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Updating IP [$ip] to [$newip]: FAILED"
                    fi
                else
                    [[ ${LOG_LEVEL} -gt 1 ]] && echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Updating IP [$ip] to [$newip]: NO CHANGE"
                fi
            fi
        fi

    done

    ## SLEEP ##
    sleep "${INTERVAL}"

done
