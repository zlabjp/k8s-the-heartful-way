#!/usr/bin/env bash
# Copyright 2020 Z Lab Corporation. All rights reserved.
#
# For the full copyright and license information, please view the LICENSE
# file that was distributed with this source code.

set -eu
export LC_ALL=C

apt update
apt install -y jq ipvsadm ipset
