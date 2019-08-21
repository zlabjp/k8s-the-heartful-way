#!/bin/bash

sed -i -e 's/PRETTY_NAME=.*$/PRETTY_NAME="Human 1.0.zlab"/' /usr/lib/os-release

/hyperkube kubelet \
    --kubeconfig=/etc/kubernetes/secrets/admin.yaml \
    --config=/var/lib/kubelet/config.yaml \
    --cni-bin-dir=/opt/cni/bin \
    --cni-conf-dir=/etc/cni/net.d \
    --network-plugin=cni \
    --hostname-override=yuanying \
    --v=2
