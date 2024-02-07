#!/bin/bash
set -e
apprise_version=$(curl -u "${GITHUB_ACTOR}:${GITHUB_TOKEN}" -fsSL "https://api.github.com/repos/caronc/apprise/releases/latest" | jq -re .tag_name)
json=$(cat VERSION.json)
jq --sort-keys \
    --arg apprise_version "${apprise_version//v/}" \
    '.apprise_version = $apprise_version' <<< "${json}" | tee VERSION.json
