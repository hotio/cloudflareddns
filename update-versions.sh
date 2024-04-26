#!/bin/bash
apprise_version=$(curl -u "${GITHUB_ACTOR}:${GITHUB_TOKEN}" -fsSL "https://api.github.com/repos/caronc/apprise/releases/latest" | jq -re .tag_name) || exit 1
[[ -z ${apprise_version} ]] && exit 0
[[ ${apprise_version} == null ]] && exit 0
version=$(git hash-object ./root/app/cloudflare-ddns.sh)
json=$(cat VERSION.json)
jq --sort-keys \
    --arg version "${version:0:7}--${apprise_version//v/}" \
    --arg apprise_version "${apprise_version//v/}" \
    '.version = $version | .apprise_version = $apprise_version' <<< "${json}" | tee VERSION.json
