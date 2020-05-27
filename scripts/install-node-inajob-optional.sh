#!/usr/bin/env bash

set -eu
export LC_ALL=C

cat <<EOF | tee /etc/netplan/50-vagrant.yaml
---
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      addresses:
      - 192.168.43.111/24
      routes:
      - to: 10.244.2.0/24
        via: 192.168.43.112
EOF
netplan apply

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
        "hairpinMode": true,
        "ipam": {
            "type": "host-local",
            "ranges": [
            [{"subnet": "10.244.1.0/24"}]
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

CONF_DIR=/vagrant/resources/kubelet-inajob
mkdir -p /var/lib/kubelet
cp ${CONF_DIR}/config.yaml /var/lib/kubelet/
cp ${CONF_DIR}/kubelet.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable kubelet
systemctl restart kubelet

iptables -t nat -A POSTROUTING -s 10.244.0.0/16 -d 10.244.0.0/16 -j RETURN
iptables -t nat -A POSTROUTING -s 10.244.0.0/16 ! -d 224.0.0.0/4 -j MASQUERADE
iptables -t nat -A POSTROUTING ! -s 10.244.0.0/16 -d 10.244.1.0/24 -j RETURN
iptables -t nat -A POSTROUTING ! -s 10.244.0.0/16 -d 10.244.0.0/16 -j MASQUERADE
