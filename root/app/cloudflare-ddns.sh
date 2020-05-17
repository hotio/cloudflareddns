#!/usr/bin/with-contenv bash
# shellcheck shell=bash

###############
## FUNCTIONS ##
###############

logger() {

          LOG_TYPE=${2}
       LOG_MESSAGE=${1}
        LOG_NUMBER="$([[ -n ${host} ]] && echo "[$((index+1))/${#cfhost[@]}] ")"
    LOG_RECORDTYPE="$([[ -n ${host} ]] && echo "[${type}] ")"
          LOG_HOST="$([[ -n ${host} ]] && echo "(${host}) ")"

    case "${LOG_TYPE}" in
        UPDATE)
            LEVEL=0
            COLOR=${GREEN}
            ;;
        ERROR)
            LEVEL=0
            COLOR=${RED}
            ;;
        WARNING)
            LEVEL=0
            COLOR=${YELLOW}
            ;;
        DEBUG)
            LEVEL=2
            COLOR=${BLUE}
            ;;
        *)
            LOG_TYPE=INFO
            LEVEL=1
            COLOR=""
            ;;
    esac

    [[ ${LOG_LEVEL} -gt ${LEVEL} ]] && >&2 printf "$(date +'%Y-%m-%d %H:%M:%S') - %s%7s - %s%s%s%s%s\n" "$(echo -e "${COLOR}")" "${LOG_TYPE}" "${LOG_NUMBER}" "${LOG_RECORDTYPE}" "${LOG_HOST}" "$(echo -e "${LOG_MESSAGE}")" "$(echo -e "${NC}")"

}
fcurl() {
    if [[ -n ${CF_APITOKEN_ZONE} ]] && [[ $* != *dns_records* ]]; then
        logger "...using [CF_APITOKEN_ZONE] to authenticate"
        curl -s -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${CF_APITOKEN_ZONE}" "$@"
    elif [[ -n ${CF_APITOKEN} ]]; then
        logger "...using [CF_APITOKEN] to authenticate"
        curl -s -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${CF_APITOKEN}" "$@"
    else
        logger "...using [CF_USER & CF_APIKEY] to authenticate"
        curl -s -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Auth-Email: ${CF_USER}" -H "X-Auth-Key: ${CF_APIKEY}" "$@"
    fi
}
finfluxdb() {
    if [[ ${INFLUXDB_ENABLED} == true ]]; then
        if result=$(curl -s -XPOST "${INFLUXDB_HOST}/query" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-urlencode "q=SHOW DATABASES"); then
            logger "Connection to InfluxDB host (${INFLUXDB_HOST}) succeeded."
            if echo "${result}" | jq -erc ".results[].series[].values[] | select(. == [\"${INFLUXDB_DB}\"])" > /dev/null; then
                logger "InfluxDB database (${INFLUXDB_DB}@${INFLUXDB_HOST}) found."
            else
                logger "InfluxDB database (${INFLUXDB_DB}@${INFLUXDB_HOST}) not found! Trying to create database..."
                result=$(curl -s -XPOST "${INFLUXDB_HOST}/query" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-urlencode "q=CREATE DATABASE ${INFLUXDB_DB}")
                if [[ ${result} == *error* ]]; then
                    logger "Error response:\n$(echo "${result}" | jq .)" ERROR
                else
                    logger "InfluxDB database (${INFLUXDB_DB}@${INFLUXDB_HOST}) created."
                fi
            fi
            scheme="domains,host=$(hostname),domain=${1},recordtype=${2} ip=\"${3}\""
            logger "Trying to write (${scheme}) to InfluxDB database (${INFLUXDB_DB}@${INFLUXDB_HOST})..."
            result=$(curl -s -XPOST "${INFLUXDB_HOST}/write?db=${INFLUXDB_DB}" -u "${INFLUXDB_USER}:${INFLUXDB_PASS}" --data-binary "${scheme}")
            if [[ ${result} == *error* ]]; then
                logger "Error response:\n$(echo "${result}" | jq .)" ERROR
            else
                logger "Wrote (${scheme}) to InfluxDB database (${INFLUXDB_DB}@${INFLUXDB_HOST})."
            fi
        else
            logger "Connection to InfluxDB host (${INFLUXDB_HOST}) failed!" ERROR
        fi
    fi
}
fapprise() {
    if [[ -n ${APPRISE} ]]; then
        for index in ${!apprise_uri[*]}; do
            logger "Sending notification with Apprise to (${apprise_uri[$index]})"
            apprise -t "Cloudflare DDNS" -b "DNS record [${2}] (${1}) has been updated to (${3})." "${apprise_uri[$index]}" || logger "Error response:\n${result}" ERROR
        done
    fi
}

#############
## STARTUP ##
#############

# SET COLORS
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
NC='\e[0m'

# SET REGEX
regexv4='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
regexv6='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'

# SET DEFAULTS
CHECK_IPV4="${CHECK_IPV4:-true}"
CHECK_IPV6="${CHECK_IPV6:-false}"
INTERVAL="${INTERVAL:-300}"
DETECTION_MODE="${DETECTION_MODE:-dig-whoami.cloudflare}"
LOG_LEVEL="${LOG_LEVEL:-3}"
INFLUXDB_ENABLED="${INFLUXDB_ENABLED:-false}"
INFLUXDB_HOST="${INFLUXDB_HOST:-http://127.0.0.1:8086}"
INFLUXDB_DB="${INFLUXDB_DB:-cloudflare_ddns}"

# READ IN VALUES
DEFAULTIFS="${IFS}"
IFS=';'
read -r -a cfhost      <<< "${CF_HOSTS}"
read -r -a cfzone      <<< "${CF_ZONES}"
read -r -a cftype      <<< "${CF_RECORDTYPES}"
read -r -a apprise_uri <<< "${APPRISE}"
IFS="${DEFAULTIFS}"

# SETUP CACHE
cache_location="${1:-/dev/shm}"
rm -f "${cache_location}"/*.cache

#################
## UPDATE LOOP ##
#################

while true; do

    ## CHECK FOR NEW IP ##
    newipv4="disabled"
    newipv6="disabled"
    logger "Attempting to find IP..."
    case "${DETECTION_MODE}" in
        dig-google.com)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
            ;;
        dig-opendns.com)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(dig -4 A +short myip.opendns.com @resolver1.opendns.com)
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(dig -6 AAAA +short myip.opendns.com @resolver1.opendns.com)
            ;;
        dig-whoami.cloudflare)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(dig -4 TXT +short whoami.cloudflare @1.1.1.1 ch | tr -d '"')
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(dig -6 TXT +short whoami.cloudflare @2606:4700:4700::1111 ch | tr -d '"')
            ;;
        curl-icanhazip.com)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 icanhazip.com)
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 icanhazip.com)
            ;;
        curl-wtfismyip.com)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 wtfismyip.com/text)
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 wtfismyip.com/text)
            ;;
        curl-showmyip.ca)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 showmyip.ca/ip.php)
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 showmyip.ca/ip.php)
            ;;
        curl-da.gd)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 da.gd/ip)
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 da.gd/ip)
            ;;
        curl-seeip.org)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 ip.seeip.org)
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 ip.seeip.org)
            ;;
        curl-ifconfig.co)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 ifconfig.co)
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 ifconfig.co)
            ;;
    esac
    logger "IPv4 detected by [${DETECTION_MODE}] is (${newipv4})"
    logger "IPv6 detected by [${DETECTION_MODE}] is (${newipv6})"

    ## UPDATE DOMAINS ##
    for index in ${!cfhost[*]}; do

        host=${cfhost[$index]}

        if [[ -n ${cftype[$index]} ]]; then
            type=${cftype[$index]}
        elif [[ -z ${type} ]]; then
            type="A"
            logger "No value was found in [CF_RECORDTYPES] for host (${host}), also no previous value was found, the default [A] is used instead." WARNING
        else
            logger "No value was found in [CF_RECORDTYPES] for host (${host}), the previous value [${type}] is used instead." WARNING
        fi

        cache="${cache_location}/cf-ddns-${type}-${host}.cache"

        case "${type}" in
            A)
                regex="${regexv4}"
                newip="${newipv4}"
                ;;
            AAAA)
                regex="${regexv6}"
                newip="${newipv6}"
                ;;
        esac

        if ! [[ ${newip} =~ ${regex} ]]; then
            logger "Returned IP (${newip}) by [${DETECTION_MODE}] is not valid for an [${type}] record! Check your connection." ERROR
        else

            if [[ -n ${cfzone[$index]} ]]; then
                zone=${cfzone[$index]}
            elif [[ -z ${zone} ]]; then
                logger "No value was found in [CF_ZONES] for host (${host}), also no previous value was found, can't do anything until you fix this!" ERROR
            else
                logger "No value was found in [CF_ZONES] for host (${host}), the previous value (${zone}) is used instead." WARNING
            fi

            ##################################################
            ## Try getting the DNS records                  ##
            ##################################################
            if [[ ! -f ${cache} ]]; then

                ## Try getting the Zone ID ##
                zoneid=""
                dnsrecords=""
                if [[ ${zone} == *.* ]]; then
                    if [[ -z ${zonelist} ]]; then
                        logger "Reading zone list from Cloudflare"
                        response=$(fcurl -X GET "https://api.cloudflare.com/client/v4/zones")
                        if [[ $(echo "${response}" | jq -r .success) == false ]]; then
                            logger "Error response:\n$(echo "${response}" | jq .)" ERROR
                        else
                            zonelist=$(echo "${response}" | jq -r '.result[] | {name, id}')
                            logger "Retrieved zone list from Cloudflare"
                            logger "Response:\n${zonelist}" DEBUG
                        fi
                    else
                        logger "Reading zone list from memory"
                    fi
                    if [[ -n ${zonelist} ]]; then
                        zoneid=$(echo "${zonelist}" | jq -r '. | select (.name == "'"${zone}"'") | .id')
                        if [[ -n ${zoneid} ]]; then
                            logger "Zone ID found for zone (${zone}) is (${zoneid})"
                        else
                            logger "Something went wrong trying to find the Zone ID of (${zone}) in the zone list!" ERROR
                        fi
                    else
                        logger "Something went wrong trying to get the zone list!" ERROR
                    fi
                elif [[ -n ${zone} ]]; then
                    zoneid=${zone} && logger "Zone ID supplied by [CF_ZONES] is (${zoneid})"
                fi

                ## Try getting the DNS records from Cloudflare ##
                if [[ -n ${zoneid} ]]; then
                    logger "Reading DNS records from Cloudflare"
                    response=$(fcurl -X GET "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records?type=${type}&name=${host}")
                    if [[ $(echo "${response}" | jq -r .success) == false ]]; then
                        logger "Error response:\n$(echo "${response}" | jq .)" ERROR
                    else
                        logger "Response:\n$(echo "${response}" | jq -r '.result[]')" DEBUG
                        dnsrecords=$(echo "${response}" | jq -r '.result[] | {name, id, zone_id, zone_name, content, type, proxied, ttl} | select (.name == "'"${host}"'") | select (.type == "'"${type}"'")')
                        if [[ -n ${dnsrecords} ]]; then
                            echo "${dnsrecords}" > "${cache}" && logger "Wrote DNS records to cache file (${cache})" INFO && logger "Data written to cache:\n$(echo "${dnsrecords}" | jq .)" DEBUG
                        else
                            logger "Something went wrong trying to find [${type}] (${host}) in the DNS records returned by Cloudflare!" ERROR
                        fi
                    fi
                fi

            else
                dnsrecords=$(cat "${cache}") && logger "Read back DNS records from cache file (${cache})" INFO && logger "Data read from cache:\n$(echo "${dnsrecords}" | jq .)" DEBUG
            fi
            ##################################################

            ##################################################
            ## If DNS records were retrieved, do the update ##
            ##################################################
            if [[ -n ${dnsrecords} ]]; then

                 zoneid=$(echo "${dnsrecords}" | jq -r '.zone_id' | head -1)
                     id=$(echo "${dnsrecords}" | jq -r '.id'      | head -1)
                proxied=$(echo "${dnsrecords}" | jq -r '.proxied' | head -1)
                    ttl=$(echo "${dnsrecords}" | jq -r '.ttl'     | head -1)
                     ip=$(echo "${dnsrecords}" | jq -r '.content' | head -1)

                if [[ ${ip} != "${newip}" ]]; then
                    logger "Updating DNS record"
                    response=$(fcurl -X PUT "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records/${id}" --data '{"id":"'"${id}"'","type":"'"${type}"'","name":"'"${host}"'","content":"'"${newip}"'","ttl":'"${ttl}"',"proxied":'"${proxied}"'}')
                    if [[ $(echo "${response}" | jq -r .success) == false ]]; then
                        logger "Error response:\n$(echo "${response}" | jq .)" ERROR
                    else
                        logger "Updating IP (${ip}) to (${newip}), status [OK]" UPDATE
                        logger "Response:\n$(echo "${response}" | jq .)" DEBUG
                        finfluxdb "${host}" "${type}" "${newip}"
                        fapprise "${host}" "${type}" "${newip}"
                        rm "${cache}" && logger "Deleted cache file (${cache})"
                    fi
                else
                    logger "Updating IP (${ip}) to (${newip}), status [NO CHANGE]"
                fi

            fi
            ##################################################

        fi

    done

    ## Reset values
    unset host
    unset zone
    unset type

    ## Go to sleep ##
    logger "Going to sleep for [${INTERVAL}] seconds..."
    sleep "${INTERVAL}"

done
