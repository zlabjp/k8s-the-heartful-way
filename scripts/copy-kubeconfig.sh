#!/usr/bin/env bash

set -eu
export LC_ALL=C

mkdir -p ~vagrant/.kube
cp /vagrant/kubernetes/admin.yaml ~vagrant/.kube/config
chown -R vagrant:vagrant ~vagrant/.kube

mkdir -p ~vagrant/secrets
cp /vagrant/kubernetes/secrets/admin.key ~vagrant/secrets/user.key
cp /vagrant/kubernetes/secrets/admin.crt ~vagrant/secrets/user.crt
chown -R vagrant:vagrant ~vagrant/secrets
