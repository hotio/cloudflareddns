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

###############
## UPDATE IP ##
###############

for index in ${!cfzone[*]}; do

    cache="/dev/shm/cf-ddns-${cfhost[$index]}-${cftype[$index]}"

    case "${cftype[$index]}" in
        A)
            regex='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
            ;;
        AAAA)
            regex='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'
            ;;
    esac

    case "${cftype[$index]}-${DETECTION_MODE}" in
        A-dig-google.com)
            newip=$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
            ;;
        AAAA-dig-google.com)
            newip=$(dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
            ;;
        A-curl-icanhazip.com)
            newip=$(curl -s -4 icanhazip.com)
            ;;
        AAAA-curl-icanhazip.com)
            newip=$(curl -s -6 icanhazip.com)
            ;;
        A-curl-wtfismyip.com)
            newip=$(curl -s -4 wtfismyip.com/text)
            ;;
        AAAA-curl-wtfismyip.com)
            newip=$(curl -s -6 wtfismyip.com/text)
            ;;
        A-curl-showmyip.ca)
            newip=$(curl -s -4 showmyip.ca/ip.php)
            ;;
        AAAA-curl-showmyip.ca)
            newip=$(curl -s -6 showmyip.ca/ip.php)
            ;;
    esac

    if ! [[ $newip =~ $regex ]]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - [${DETECTION_MODE}] - [${cfhost[$index]}] - [${cftype[$index]}] - Returned current IP is not valid! Check your connection." >> "${LOG}"
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
