#!/bin/bash
set -exuo pipefail

version_apprise=$(curl -fsSL "https://api.github.com/repos/caronc/apprise/releases/latest" | jq -re .tag_name)
json=$(cat meta.json)
jq --sort-keys \
    --arg version_apprise "${version_apprise//v/}" \
    '.version_apprise = $version_apprise' <<< "${json}" | tee meta.json
