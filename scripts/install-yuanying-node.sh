#!/usr/bin/env bash

set -eu
export LC_ALL=C

if [[ $(hostname) != "yuanying" ]]; then
    exit
fi

ip route add 10.244.1.0/24 via 192.168.43.111 | true

mkdir -p /etc/cni/net.d

cat <<EOF > /etc/cni/net.d/0-cni.conflist
{
  "name": "cbr0",
  "plugins": [
    {
        "name": "bridge",
        "type": "bridge",
        "bridge": "cni0",
        "isGateway": true,
        "ipMasq": true,
        "ipam": {
            "type": "host-local",
            "ranges": [
            [{"subnet": "10.244.2.0/24"}]
            ],
            "routes": [{"dst": "0.0.0.0/0"}]
        }
    },
    {
        "type": "loopback"
    }
  ]
}
EOF

CONF_DIR=/vagrant/resources/kubelet-yuanying
mkdir -p /var/lib/kubelet
cp ${CONF_DIR}/config.yaml /var/lib/kubelet/
cp ${CONF_DIR}/kubelet.service /etc/systemd/system/
cp ${CONF_DIR}/kube-proxy.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable kubelet
systemctl enable kube-proxy
systemctl restart kubelet
systemctl restart kube-proxy
