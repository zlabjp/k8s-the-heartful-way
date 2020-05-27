#!/usr/bin/env bash

set -eu
export LC_ALL=C

CNI_PATH=/opt/cni/bin
if [[ ! -f ${CNI_PATH}/bridge ]]; then
  mkdir -p ${CNI_PATH}
  tar zxvf /vagrant/cache/cni-plugin.tgz -C ${CNI_PATH}
fi
