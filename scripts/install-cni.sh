#!/usr/bin/env bash
# Copyright 2020 Z Lab Corporation. All rights reserved.
#
# For the full copyright and license information, please view the LICENSE
# file that was distributed with this source code.

set -eu
export LC_ALL=C

CNI_PATH=/opt/cni/bin
if [[ ! -f ${CNI_PATH}/bridge ]]; then
  mkdir -p ${CNI_PATH}
  tar zxvf /vagrant/cache/cni-plugin.tgz -C ${CNI_PATH}
fi
