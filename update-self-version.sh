#!/bin/bash
if ! git diff --quiet; then
    json=$(cat VERSION.json)
    jq --sort-keys \
        --arg version "$(date -u +'%Y%m%d%H%M%S')" \
        '.version = $version' <<< "${json}" | tee VERSION.json
fi
