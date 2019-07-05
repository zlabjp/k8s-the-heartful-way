#!/usr/bin/env bash

set -eu
export LC_ALL=C

KUBECTL_PATH=/usr/local/bin/kubectl
cp /vagrant/cache/kubectl ${KUBECTL_PATH}
chmod +x ${KUBECTL_PATH}
