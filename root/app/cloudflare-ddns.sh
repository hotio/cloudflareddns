#!/usr/bin/with-contenv bash
# shellcheck shell=bash

umask "${UMASK}"

###################
## CONFIGURATION ##
###################

cfuser="${CF_USER}"
cfapikey="${CF_APIKEY}"

DEFAULTIFS="${IFS}"
IFS=';'
read -r -a cfzone <<< "${CF_ZONES}"
read -r -a cfhost <<< "${CF_HOSTS}"
read -r -a cftype <<< "${CF_RECORDTYPES}"
read -r -a mode <<< "${MODES}"
IFS="${DEFAULTIFS}"

###############
## UPDATE IP ##
###############

for index in ${!cfzone[*]}; do

    cache="/dev/shm/cf-ddns-${cfhost[$index]}-${cftype[$index]}"

    case "${mode[$index]}" in
        4)
            regex='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
            newip=$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
            #newip=$(curl -s -4 icanhazip.com)
            ;;
        6)
            regex='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'
            newip=$(dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
            #newip=$(curl -s -6 icanhazip.com)
            ;;
    esac

    if ! [[ $newip =~ $regex ]]; then
        echo "$(date +'%H:%M:%S') - ${cfhost[$index]} (${cftype[$index]}): Returned IP from detection service is not valid! Check your connection." >> "${CONFIG_DIR}/app/cloudflare-ddns.log"
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
            echo "$(date +'%H:%M:%S') - ${cfhost[$index]} (${cftype[$index]}): Returned IP from Cloudflare is not valid! Check your connection or configuration." >> "${CONFIG_DIR}/app/cloudflare-ddns.log"
        else
            if [[ "$ip" != "$newip" ]]; then
                if [[ $(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$id" -H "X-Auth-Email: $cfuser" -H "X-Auth-Key: $cfapikey" -H "Content-Type: application/json" --data '{"id":"'"$id"'","type":"'"${cftype[$index]}"'","name":"'"${cfhost[$index]}"'","content":"'"$newip"'","proxied":'"$proxied"'}' | jq '.success') == true ]]; then
                    echo "$(date +'%H:%M:%S') - ${cfhost[$index]} (${cftype[$index]}): Updating IP [$ip] to [$newip]: OK" >> "${CONFIG_DIR}/app/cloudflare-ddns.log"
                    rm "$cache"
                else
                    echo "$(date +'%H:%M:%S') - ${cfhost[$index]} (${cftype[$index]}): Updating IP [$ip] to [$newip]: FAILED" >> "${CONFIG_DIR}/app/cloudflare-ddns.log"
                fi
            else
                echo "$(date +'%H:%M:%S') - ${cfhost[$index]} (${cftype[$index]}): Updating IP [$ip] to [$newip]: NO CHANGE" >> "${CONFIG_DIR}/app/cloudflare-ddns.log"
            fi
        fi
    fi

done
