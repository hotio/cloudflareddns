#!/bin/bash

version_apprise=$(curl -u "${GITHUB_ACTOR}:${GITHUB_TOKEN}" -fsSL "https://api.github.com/repos/caronc/apprise/releases/latest" | jq -r .tag_name | sed s/v//g)
[[ -z ${version_apprise} ]] && exit 0
version_json=$(cat ./VERSION.json)
jq '.apprise_version = "'"${version_apprise}"'"' <<< "${version_json}" > VERSION.json
