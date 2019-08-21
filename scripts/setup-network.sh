#!/usr/bin/env bash

set -eu
export LC_ALL=C

echo "#{cluster_ssh_public_key}" >> ~vagrant/.ssh/authorized_keys
echo "#{cluster_ssh_private_key}" > ~vagrant/.ssh/id_rsa
echo "#{cluster_ssh_public_key}" > ~root/.ssh/authorized_keys
echo "#{cluster_ssh_private_key}" > ~root/.ssh/id_rsa
chmod 700 ~root/.ssh
chmod 600 ~root/.ssh/id_rsa

# Update /etc/hosts
if [[ ! -f /etc/hosts.bak ]]; then
  cp /etc/hosts /etc/hosts.bak
fi
cp /etc/hosts.bak /etc/hosts
cat <<EOL >> /etc/hosts
192.168.43.101 master01
192.168.43.111 inajob
192.168.43.112 yuanying
EOL
iptables -P FORWARD ACCEPT

if [[ $(hostname) == "master01" ]]; then
  cat <<EOF | tee /etc/netplan/50-vagrant.yaml
---
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      addresses:
      - 192.168.43.101/24
      routes:
      - to: 10.244.1.0/24
        via: 192.168.43.111
      - to: 10.244.2.0/24
        via: 192.168.43.112
EOF
  netplan apply
fi
