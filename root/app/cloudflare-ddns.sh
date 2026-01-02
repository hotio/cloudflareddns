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
        LOG_HOST="[${host}] "
    else
        unset LOG_NUMBER
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

    [[ ${LOG_LEVEL} -gt ${LEVEL} ]] && printf "$(date +'%Y-%m-%d %H:%M:%S') - %s%7s - %s%s%b%s\n" "${COLOR}" "${LOG_TYPE}" "${LOG_NUMBER}" "${LOG_HOST}" "${LOG_MESSAGE}" "${NC}"

}
fcurl() {
    if [[ -n ${CF_APITOKEN} ]]; then
        curl -s -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${CF_APITOKEN}" "$@"
    else
        curl -s -H "Accept: application/json" -H "Content-Type: application/json" -H "X-Auth-Email: ${CF_USER}" -H "X-Auth-Key: ${CF_APIKEY}" "$@"
    fi
}
fapprise() {
    if [[ -n ${APPRISE} ]]; then
        for index in ${!apprise_uri[*]}; do
            apprise_uri=${apprise_uri[$index]//[[:space:]]/}
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
IFS=$'\n' read -r -d '' -a cfhost      < <(awk -F'[,;]' '{ for( i=1; i<=NF; i++ ) print $i }' <<< "${CF_HOSTS}")
IFS=$'\n' read -r -d '' -a apprise_uri < <(awk -F'[,;]' '{ for( i=1; i<=NF; i++ ) print $i }' <<< "${APPRISE}")

# SETUP CACHE
cache_location="${1:-/dev/shm}"
rm -f "${cache_location}"/*.cache

#################
## UPDATE LOOP ##
#################

while true; do

    ## CHECK FOR NEW IP ##
    case "${DETECTION_MODE}" in
        dig-google.com)
            [[ ${UPDATE_IPV4} == "true" ]] && newipv4=$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com 2>/dev/null | sed -e 's/"//g' -e '/;.*/d')
            [[ ${UPDATE_IPV6} == "true" ]] && newipv6=$(dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com 2>/dev/null | sed -e 's/"//g' -e '/;.*/d')
            ;;
        dig-opendns.com)
            [[ ${UPDATE_IPV4} == "true" ]] && newipv4=$(dig -4 A +short myip.opendns.com @resolver1.opendns.com 2>/dev/null | sed -e 's/"//g' -e '/;.*/d')
            [[ ${UPDATE_IPV6} == "true" ]] && newipv6=$(dig -6 AAAA +short myip.opendns.com @resolver1.opendns.com 2>/dev/null | sed -e 's/"//g' -e '/;.*/d')
            ;;
        dig-whoami.cloudflare)
            [[ ${UPDATE_IPV4} == "true" ]] && newipv4=$(dig -4 TXT +short whoami.cloudflare @1.1.1.1 ch 2>/dev/null | sed -e 's/"//g' -e '/;.*/d')
            [[ ${UPDATE_IPV6} == "true" ]] && newipv6=$(dig -6 TXT +short whoami.cloudflare @2606:4700:4700::1111 ch 2>/dev/null | sed -e 's/"//g' -e '/;.*/d')
            ;;
        curl-icanhazip.com)
            [[ ${UPDATE_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 icanhazip.com)
            [[ ${UPDATE_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 icanhazip.com)
            ;;
        curl-wtfismyip.com)
            [[ ${UPDATE_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 wtfismyip.com/text)
            [[ ${UPDATE_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 wtfismyip.com/text)
            ;;
        curl-showmyip.ca)
            [[ ${UPDATE_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 showmyip.ca/ip.php)
            [[ ${UPDATE_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 showmyip.ca/ip.php)
            ;;
        curl-da.gd)
            [[ ${UPDATE_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 da.gd/ip)
            [[ ${UPDATE_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 da.gd/ip)
            ;;
        curl-seeip.org)
            [[ ${UPDATE_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 ip.seeip.org)
            [[ ${UPDATE_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 ip.seeip.org)
            ;;
        curl-ifconfig.co)
            [[ ${UPDATE_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 ifconfig.co)
            [[ ${UPDATE_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 ifconfig.co)
            ;;
        curl-ipw.cn)
            [[ ${UPDATE_IPV4} == "true" ]] && newipv4=$(curl -fsL -4 4.ipw.cn)
            [[ ${UPDATE_IPV6} == "true" ]] && newipv6=$(curl -fsL -6 6.ipw.cn)
            ;;
        local:*)
            [[ ${UPDATE_IPV4} == "true" ]] && newipv4=$(ip addr show "${DETECTION_MODE/local:/}" 2>/dev/null | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}' | head -1)
            [[ ${UPDATE_IPV6} == "true" ]] && newipv6=$(ip addr show "${DETECTION_MODE/local:/}" 2>/dev/null | awk '$1 == "inet6" && $6 == "noprefixroute" {gsub(/\/.*$/, "", $2); print $2 }' | head -1)
            ;;
    esac
    [[ ${UPDATE_IPV4} == "true" ]] && logger "IPv4 detected by [${DETECTION_MODE}] is [${newipv4}]."
    [[ ${UPDATE_IPV6} == "true" ]] && logger "IPv6 detected by [${DETECTION_MODE}] is [${newipv6}]."

    ## UPDATE DOMAINS ##
    for index in ${!cfhost[*]}; do
        host=${cfhost[$index]//[[:space:]]/}
        cache="${cache_location}/cf-ddns-${host}.cache"
        zone=$(awk -F"." -v OFS="." '{print $(NF-1),$(NF)}' <<< "${host}")

        ##################################################
        ## Try getting the DNS records                  ##
        ##################################################
        if [[ ! -f ${cache} ]]; then
            ## Try getting the Zone ID ##
            zoneid=""
            if [[ -z ${zonelist} ]]; then
                logger "Requesting zone list from Cloudflare."
                response=$(fcurl -X GET "https://api.cloudflare.com/client/v4/zones" | jq -r '.result[] | {id, name}')
                if [[ -n "${response}" ]]; then
                    zonelist=$(jq . <<< "${response}")
                    logger "Response:\n${zonelist}" DEBUG
                    logger "Retrieved zone list from Cloudflare."
                else
                    logger "An unexpected error occured!" ERROR
                fi
            fi
            if [[ -n ${zonelist} ]]; then
                zoneid=$(jq -r 'select (.name == "'"${zone}"'") | .id' <<< "${zonelist}")
                if [[ -n ${zoneid} ]]; then
                    logger "Zone ID [${zoneid}] found for zone [${zone}]."
                else
                    logger "Couldn't find the Zone ID for zone [${zone}]!" ERROR
                fi
            fi

            ## Try getting the DNS record from Cloudflare ##
            dnsrecord=""
            if [[ -n ${zoneid} ]]; then
                logger "Requesting DNS records from Cloudflare."
                dnsrecord=$(fcurl -X GET "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records?name=${host}" | jq -rc '.result[]|select(.type=="A" or .type=="AAAA")| {id, name, type, content, proxied, ttl}')
                if [[ -n "${dnsrecord}" ]]; then
                    logger "Response:\n$(jq . <<< "${dnsrecord}")" DEBUG
                    logger "Writing DNS records to cache file [${cache}]." INFO
                    printf "%s" "${dnsrecord}" > "${cache}"
                else
                    logger "An unexpected error occured!" ERROR
                fi
            fi
        else
            logger "Reading DNS records from cache file [${cache}]." INFO
            dnsrecord=$(<"${cache}")
            logger "Data read from cache:\n$(jq . <<< "${dnsrecord}")" DEBUG
        fi

        ##################################################
        ## If DNS records were retrieved, do the update ##
        ##################################################
        if [[ -n ${dnsrecord} ]]; then
            while IFS=$'\n' read -r record; do
                id=$(jq -r '.id'      <<< "${record}")
                proxied=$(jq -r '.proxied' <<< "${record}")
                ttl=$(jq -r '.ttl'     <<< "${record}")
                ip=$(jq -r '.content' <<< "${record}")
                type=$(jq -r '.type' <<< "${record}")

                case "${type}" in
                    A)
                        [[ ${UPDATE_IPV4} != "true" ]] && logger "[${id}][${type}] Update is not wanted." && continue
                        regex="${regexv4}"
                        newip="${newipv4}"
                        ;;
                    AAAA)
                        [[ ${UPDATE_IPV6} != "true" ]] && logger "[${id}][${type}] Update is not wanted." && continue
                        regex="${regexv6}"
                        newip="${newipv6}"
                        ;;
                esac
                if ! [[ ${newip} =~ ${regex} ]]; then
                    logger "[${id}][${type}] Returned IP [${newip}] is not valid!" ERROR
                    continue
                fi

                logger "[${id}][${type}] Checking if update is needed."
                if [[ ${ip} != "${newip}" ]]; then
                    logger "[${id}][${type}] Updating DNS record."
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
                    logger "[${id}][${type}] No update needed."
                fi
            done <<< "${dnsrecord}"
        fi
    done

    ## Go to sleep or exit ##
    if [[ "${INTERVAL}" == 0 ]]; then
        logger "INTERVAL set to [${INTERVAL}] seconds. Exiting..."
        exit 0
    else
        logger "Going to sleep for [${INTERVAL}] seconds..."
        sleep "${INTERVAL}"
    fi
done
