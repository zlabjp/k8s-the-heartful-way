#!/usr/bin/env bash

set -eu
export LC_ALL=C

if [[ $(hostname) != "yuanying" ]]; then
    exit
fi

ip route add 10.244.1.0/24 via 192.168.43.111 | true
