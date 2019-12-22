#!/bin/bash

if [[ ${1} == "checkdigests" ]]; then
    docker pull hotio/base:stable-linux-arm64
    docker pull hotio/base:stable-linux-arm
    docker pull hotio/base:stable-linux-amd64
    docker inspect --format='{{index .RepoDigests 0}}' hotio/base:stable-linux-arm64 >  upstream_digests.txt
    docker inspect --format='{{index .RepoDigests 0}}' hotio/base:stable-linux-arm   >> upstream_digests.txt
    docker inspect --format='{{index .RepoDigests 0}}' hotio/base:stable-linux-amd64 >> upstream_digests.txt
fi
