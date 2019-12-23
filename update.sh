#!/bin/bash

if [[ ${1} == "checkdigests" ]]; then
    image="hotio/base:stable-linux-amd64" && docker pull ${image} && digest=$(docker inspect --format='{{index .RepoDigests 0}}' ${image}) && sed -i "s#FROM .*\$#FROM ${digest}#g" ./linux-amd64.Dockerfile
    image="hotio/base:stable-linux-arm"   && docker pull ${image} && digest=$(docker inspect --format='{{index .RepoDigests 0}}' ${image}) && sed -i "s#FROM .*\$#FROM ${digest}#g" ./linux-arm.Dockerfile
    image="hotio/base:stable-linux-arm64" && docker pull ${image} && digest=$(docker inspect --format='{{index .RepoDigests 0}}' ${image}) && sed -i "s#FROM .*\$#FROM ${digest}#g" ./linux-arm64.Dockerfile
fi
