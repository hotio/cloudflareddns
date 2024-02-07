#!/bin/bash

apprise_version=$(curl -u "${GITHUB_ACTOR}:${GITHUB_TOKEN}" -fsSL "https://api.github.com/repos/caronc/apprise/releases/latest" | jq -r .tag_name | sed s/v//g)
[[ -z ${apprise_version} ]] && exit 0
json=$(cat VERSION.json)
jq --sort-keys \
    --arg apprise_version "${apprise_version}" \
    '.apprise_version = $apprise_version' <<< "${json}" > VERSION.json
