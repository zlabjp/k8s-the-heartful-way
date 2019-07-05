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
