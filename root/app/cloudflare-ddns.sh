#!/usr/bin/with-contenv bash
# shellcheck shell=bash

umask "${UMASK}"

###################
## CONFIGURATION ##
###################

LOG="${CONFIG_DIR}/app/cloudflare-ddns.log"

cfuser="${CF_USER}"
cfapikey="${CF_APIKEY}"

DEFAULTIFS="${IFS}"
IFS=';'
read -r -a cfzone <<< "${CF_ZONES}"
read -r -a cfhost <<< "${CF_HOSTS}"
read -r -a cftype <<< "${CF_RECORDTYPES}"
IFS="${DEFAULTIFS}"

######################
## CHECK FOR NEW IP ##
######################

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

regexv4='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
regexv6='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'

#######################################
## LOG CONNECTION STATUS TO INFLUXDB ##
#######################################

if [[ ${INFLUXDB_ENABLED} == "true" ]]; then
    if [[ $newipv4 =~ $regexv4 ]]; then
        curl -s -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "connection,host=$(hostname),type=ipv4 status=1"
    else
        curl -s -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "connection,host=$(hostname),type=ipv4 status=0"
    fi

    if [[ $newipv6 =~ $regexv6 ]]; then
        curl -s -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "connection,host=$(hostname),type=ipv6 status=1"
    else
        curl -s -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "connection,host=$(hostname),type=ipv6 status=0"
    fi
fi

####################
## UPDATE DOMAINS ##
####################

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
        echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Returned IP by \"${DETECTION_MODE}\" is not valid! Check your connection." >> "${LOG}"
    else
        if [[ ! -f "$cache" ]]; then
            zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" -H "X-Auth-Email: $cfuser" -H "X-Auth-Key: $cfapikey" -H "Content-Type: application/json" | jq -r '.result[] | select (.name == "'"${cfzone[$index]}"'") | .id')
            dnsrecords=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records" -H "X-Auth-Email: $cfuser" -H "X-Auth-Key: $cfapikey" -H "Content-Type: application/json" | jq -r '.result[] | {name, id, zone_id, zone_name, content, type, proxied} | select (.name == "'"${cfhost[$index]}"'") | select (.type == "'"${cftype[$index]}"'")')
            echo "$dnsrecords" > "$cache"
        else
            dnsrecords=$(cat "$cache")
            zoneid=$(echo "$dnsrecords" | jq -r '.zone_id' | head -1)
        fi
        id=$(echo "$dnsrecords" | jq -r '.id' | head -1)
        proxied=$(echo "$dnsrecords" | jq -r '.proxied' | head -1)
        ip=$(echo "$dnsrecords" | jq -r '.content' | head -1)
        if ! [[ $ip =~ $regex ]]; then
            echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Returned IP by \"Cloudflare\" is not valid! Check your connection or configuration." >> "${LOG}"
        else
            if [[ "$ip" != "$newip" ]]; then
                if [[ $(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$id" -H "X-Auth-Email: $cfuser" -H "X-Auth-Key: $cfapikey" -H "Content-Type: application/json" --data '{"id":"'"$id"'","type":"'"${cftype[$index]}"'","name":"'"${cfhost[$index]}"'","content":"'"$newip"'","proxied":'"$proxied"'}' | jq '.success') == true ]]; then
                    echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Updating IP [$ip] to [$newip]: OK" >> "${LOG}"
                    [[ ${INFLUXDB_ENABLED} == "true" ]] && curl -s -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "domains,host=$(hostname),domain=${cfhost[$index]},recordtype=${cftype[$index]} ip=\"$newip\""
                    rm "$cache"
                else
                    echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Updating IP [$ip] to [$newip]: FAILED" >> "${LOG}"
                fi
            else
                echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Updating IP [$ip] to [$newip]: NO CHANGE" >> "${LOG}"
            fi
        fi
    fi

done
