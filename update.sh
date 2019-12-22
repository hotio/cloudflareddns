#!/bin/bash

if [[ ${1} == "checkpackages" ]]; then
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
    docker run --rm -v "${GITHUB_WORKSPACE}":/github -t hotio/base:stable-linux-arm64 bash -c 'apt list --installed > /github/upstream_packages.arm64.txt'
    docker run --rm -v "${GITHUB_WORKSPACE}":/github -t hotio/base:stable-linux-arm   bash -c 'apt list --installed > /github/upstream_packages.arm.txt'
    docker run --rm -v "${GITHUB_WORKSPACE}":/github -t hotio/base:stable-linux-amd64 bash -c 'apt list --installed > /github/upstream_packages.amd64.txt'
fi
