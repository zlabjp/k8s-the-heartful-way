#!/bin/bash
# Copyright 2020 Z Lab Corporation. All rights reserved.
#
# For the full copyright and license information, please view the LICENSE
# file that was distributed with this source code.

sed -i -e 's/PRETTY_NAME=.*$/PRETTY_NAME="Human 1.0.zlab"/' /usr/lib/os-release

/hyperkube kubelet \
    --kubeconfig=/etc/kubernetes/secrets/admin.yaml \
    --config=/var/lib/kubelet/config.yaml \
    --cni-bin-dir=/opt/cni/bin \
    --cni-conf-dir=/etc/cni/net.d \
    --network-plugin=cni \
    --hostname-override=inajob \
    --v=2
