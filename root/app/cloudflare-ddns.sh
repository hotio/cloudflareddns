#!/command/with-contenv bash
# shellcheck shell=bash

###############
## FUNCTIONS ##
###############

logger() {

    LOG_TYPE=${2}
    LOG_MESSAGE=${1}
    if [[ -n ${host} ]]; then
        LOG_NUMBER="[$((index+1))/${#cfhost[@]}] "
        LOG_RECORDTYPE="[${type}] "
        LOG_ZONE="[${zone}] "
        LOG_HOST="[${host}] "
    else
        unset LOG_NUMBER
        unset LOG_RECORDTYPE
        unset LOG_ZONE
        unset LOG_HOST
    fi

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
            COLOR=${NC}
            ;;
    esac

    [[ ${LOG_LEVEL} -gt ${LEVEL} ]] && printf "$(date +'%Y-%m-%d %H:%M:%S') - %s%7s - %s%s%s%s%b%s\n" "${COLOR}" "${LOG_TYPE}" "${LOG_NUMBER}" "${LOG_RECORDTYPE}" "${LOG_ZONE}" "${LOG_HOST}" "${LOG_MESSAGE}" "${NC}"

}
fcurl() {
    if [[ -n ${CF_APITOKEN_ZONE} ]] && [[ $* != *dns_records* ]]; then
        curl -s -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${CF_APITOKEN_ZONE}" "$@"
    elif [[ -n ${CF_APITOKEN} ]]; then
        curl -s -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${CF_APITOKEN}" "$@"
    else
        curl -s -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Auth-Email: ${CF_USER}" -H "X-Auth-Key: ${CF_APIKEY}" "$@"
    fi
}
fapprise() {
    if [[ -n ${APPRISE} ]]; then
        for index in ${!apprise_uri[*]}; do
            logger "Sending notification with Apprise to [${apprise_uri[$index]}]."
            result=$(apprise -v -t "Cloudflare DDNS - [${1}]" -b "DNS record [${2}] [${1}] has been updated from [${4}] to [${3}]." "${apprise_uri[$index]}") || logger "Error response:\n${result}" ERROR
        done
    fi
}
fjson() {
    updates_json="${cache_location}/cf-ddns-updates.json"
    logger "Writing domain update to [${updates_json}]."
    printf '{"domain":"%s","recordtype":"%s","ip":"%s","timestamp":"%s"}\n' "${1}" "${2}" "${3}" "$(date --utc +%FT%TZ)" >> "${updates_json}"
}

#############
## STARTUP ##
#############

# SET COLORS
RED=$(tput -Txterm setaf 1)
GREEN=$(tput -Txterm setaf 2)
YELLOW=$(tput -Txterm setaf 3)
BLUE=$(tput -Txterm setaf 4)
NC=$(tput -Txterm sgr0)

# SET REGEX
regexv4='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
regexv6='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'

# SET DEFAULTS
INTERVAL="${INTERVAL:-300}"
DETECTION_MODE="${DETECTION_MODE:-dig-whoami.cloudflare}"
LOG_LEVEL="${LOG_LEVEL:-3}"

# READ IN VALUES
VALUE_SEPARATOR_RE=$'[[:space:]]*;[[:space:]]*'
IFS=$'\n' read -r -d '' -a cfhost      < <(awk -F${VALUE_SEPARATOR_RE} '{ for( i=1; i<=NF; i++ ) print $i }' <<< "${CF_HOSTS}")
IFS=$'\n' read -r -d '' -a cfzone      < <(awk -F${VALUE_SEPARATOR_RE} '{ for( i=1; i<=NF; i++ ) print $i }' <<< "${CF_ZONES}")
IFS=$'\n' read -r -d '' -a cftype      < <(awk -F${VALUE_SEPARATOR_RE} '{ for( i=1; i<=NF; i++ ) print $i }' <<< "${CF_RECORDTYPES}")
IFS=$'\n' read -r -d '' -a apprise_uri < <(awk -F${VALUE_SEPARATOR_RE} '{ for( i=1; i<=NF; i++ ) print $i }' <<< "${APPRISE}")
unset VALUE_SEPARATOR_RE

# SETUP CACHE
cache_location="${1:-/dev/shm}"
rm -f "${cache_location}"/*.cache

# CHECK WHAT IP CHECK WE NEED TO ENABLE
for index in ${!cftype[*]}; do
    [[ ${cftype[$index]} == "A" ]]    && CHECK_IPV4="true"
    [[ ${cftype[$index]} == "AAAA" ]] && CHECK_IPV6="true"
done

#################
## UPDATE LOOP ##
#################

while true; do

    ## CHECK FOR NEW IP ##
    case "${DETECTION_MODE}" in
        dig-google.com)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com 2>/dev/null | tr -d '"')
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com 2>/dev/null | tr -d '"')
            ;;
        dig-opendns.com)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(dig -4 A +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(dig -6 AAAA +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)
            ;;
        dig-whoami.cloudflare)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(dig -4 TXT +short whoami.cloudflare @1.1.1.1 ch 2>/dev/null | tr -d '"')
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(dig -6 TXT +short whoami.cloudflare @2606:4700:4700::1111 ch 2>/dev/null | tr -d '"')
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
        curl-ipw.cn)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 4.ipw.cn)
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 6.ipw.cn)
            ;;
        local:*)
            [[ ${CHECK_IPV4} == "true" ]] && newipv4=$(ip addr show "${DETECTION_MODE/local:/}" 2>/dev/null | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}' | head -1)
            [[ ${CHECK_IPV6} == "true" ]] && newipv6=$(ip addr show "${DETECTION_MODE/local:/}" 2>/dev/null | awk '$1 == "inet6" && $6 == "noprefixroute" {gsub(/\/.*$/, "", $2); print $2 }' | head -1)
            ;;
    esac
    [[ ${CHECK_IPV4} == "true" ]] && logger "IPv4 detected by [${DETECTION_MODE}] is [${newipv4}]."
    [[ ${CHECK_IPV6} == "true" ]] && logger "IPv6 detected by [${DETECTION_MODE}] is [${newipv6}]."

    ## UPDATE DOMAINS ##
    for index in ${!cfhost[*]}; do

        host=${cfhost[$index]}

        if [[ -n ${cftype[$index]} ]]; then
            type=${cftype[$index]}
        elif [[ -z ${type} ]]; then
            logger "No value was found in [CF_RECORDTYPES] for host [${host}], also no previous value was found, can't do anything until you fix this!" ERROR
            break
        else
            logger "No value was found in [CF_RECORDTYPES] for host [${host}], the previous value [${type}] is used instead." WARNING
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
            logger "Returned IP [${newip}] by [${DETECTION_MODE}] is not valid for an [${type}] record! Check your connection or configuration." ERROR
        else

            if [[ -n ${cfzone[$index]} ]]; then
                zone=${cfzone[$index]}
            elif [[ -z ${zone} ]]; then
                logger "No value was found in [CF_ZONES] for host [${host}], also no previous value was found, can't do anything until you fix this!" ERROR
                break
            else
                logger "No value was found in [CF_ZONES] for host [${host}], the previous value [${zone}] is used instead." WARNING
            fi

            ##################################################
            ## Try getting the DNS records                  ##
            ##################################################
            if [[ ! -f ${cache} ]]; then
                ## Try getting the Zone ID ##
                zoneid=""
                dnsrecord=""
                if [[ ${zone} == *.* ]]; then
                    if [[ -z ${zonelist} ]]; then
                        logger "Reading zone list from Cloudflare."
                        response=$(fcurl -X GET "https://api.cloudflare.com/client/v4/zones")
                        if [[ $(jq -r '.success' <<< "${response}") == false ]]; then
                            logger "Error response:\n$(jq . <<< "${response}")" ERROR
                        elif [[ $(jq -r '.success' <<< "${response}") == true ]] && [[ $(jq -r '.result_info.total_count' <<< "${response}") == 0 ]]; then
                            logger "No zone list was returned!" ERROR
                        elif [[ $(jq -r '.success' <<< "${response}") == true ]]; then
                            zonelist=$(jq . <<< "${response}")
                            logger "Response:\n${zonelist}" DEBUG
                            logger "Retrieved zone list from Cloudflare."
                        else
                            logger "An unexpected error occured!" ERROR
                        fi
                    else
                        logger "Reading zone list from memory."
                    fi
                    if [[ -n ${zonelist} ]]; then
                        zoneid=$(jq -r '.result[] | select (.name == "'"${zone}"'") | .id' <<< "${zonelist}")
                        if [[ -n ${zoneid} ]]; then
                            logger "Zone ID [${zoneid}] found for zone [${zone}]."
                        else
                            logger "Couldn't find the Zone ID for zone [${zone}]!" ERROR
                        fi
                    fi
                elif [[ -n ${zone} ]]; then
                    zoneid=${zone}
                    logger "Zone ID supplied by [CF_ZONES] is [${zoneid}]."
                fi

                ## Try getting the DNS record from Cloudflare ##
                if [[ -n ${zoneid} ]]; then
                    logger "Reading DNS record from Cloudflare."
                    response=$(fcurl -X GET "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records?type=${type}&name=${host}")
                    if [[ $(jq -r '.success' <<< "${response}") == false ]]; then
                        logger "Error response:\n$(jq . <<< "${response}")" ERROR
                    elif [[ $(jq -r '.success' <<< "${response}") == true ]] && [[ $(jq -r '.result_info.total_count' <<< "${response}") == 0 ]]; then
                        logger "No DNS record was returned!" ERROR
                    elif [[ $(jq -r '.success' <<< "${response}") == true ]]; then
                        logger "Response:\n$(jq . <<< "${response}")" DEBUG
                        dnsrecord=$(jq -r '.result[0] | {name, id, zone_id, zone_name, content, type, proxied, ttl}' <<< "${response}")
                        logger "Writing DNS record to cache file [${cache}]." INFO
                        printf "%s" "${dnsrecord}" > "${cache}"
                        logger "Data written to cache:\n$(jq . <<< "${dnsrecord}")" DEBUG
                    else
                        logger "An unexpected error occured!" ERROR
                    fi
                fi
            else
                logger "Reading DNS record from cache file [${cache}]." INFO
                dnsrecord=$(<"${cache}")
                logger "Data read from cache:\n$(jq . <<< "${dnsrecord}")" DEBUG
            fi

            ##################################################
            ## If DNS records were retrieved, do the update ##
            ##################################################
            if [[ -n ${dnsrecord} ]]; then
                 zoneid=$(jq -r '.zone_id' <<< "${dnsrecord}")
                     id=$(jq -r '.id'      <<< "${dnsrecord}")
                proxied=$(jq -r '.proxied' <<< "${dnsrecord}")
                    ttl=$(jq -r '.ttl'     <<< "${dnsrecord}")
                     ip=$(jq -r '.content' <<< "${dnsrecord}")

                logger "Checking if update is needed."
                if [[ ${ip} != "${newip}" ]]; then
                    logger "Updating DNS record."
                    response=$(fcurl -X PUT "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records/${id}" --data '{"id":"'"${id}"'","type":"'"${type}"'","name":"'"${host}"'","content":"'"${newip}"'","ttl":'"${ttl}"',"proxied":'"${proxied}"'}')
                    if [[ $(jq -r '.success' <<< "${response}") == false ]]; then
                        logger "Error response:\n$(jq . <<< "${response}")" ERROR
                    elif [[ $(jq -r '.success' <<< "${response}") == true ]]; then
                        logger "Response:\n$(jq . <<< "${response}")" DEBUG
                        logger "Updated IP [${ip}] to [${newip}]." UPDATE
                        logger "Deleting cache file [${cache}]."
                        rm "${cache}"
                        fjson "${host}" "${type}" "${newip}"
                        fapprise "${host}" "${type}" "${newip}" "${ip}"
                    else
                        logger "An unexpected error occured!" ERROR
                    fi
                else
                    logger "No update needed."
                fi
            fi

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
