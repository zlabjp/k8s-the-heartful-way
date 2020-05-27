#!/usr/bin/env bash
# Copyright 2020 Z Lab Corporation. All rights reserved.
#
# For the full copyright and license information, please view the LICENSE
# file that was distributed with this source code.

set -eu
export LC_ALL=C

KUBECTL_PATH=/usr/local/bin/kubectl
cp /vagrant/cache/kubectl ${KUBECTL_PATH}
chmod +x ${KUBECTL_PATH}
