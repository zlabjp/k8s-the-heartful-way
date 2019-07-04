#!/usr/bin/env bash

set -eu
export LC_ALL=C

KUBE_ROOT="/etc/kubernetes"
KUBE_CERTS_DIR="${KUBE_ROOT}/secrets"

CA_CERT=${KUBE_CERTS_DIR}/ca.crt
CLIENT_KEY=${KUBE_CERTS_DIR}/admin.key
CLIENT_CERT=${KUBE_CERTS_DIR}/admin.crt

KUBE_CONFIG=${KUBE_ROOT}/admin.yaml

CA_DATA=$(cat ${CA_CERT} | base64 | tr -d '\n')
CLIENT_CERTS_DATA=$(cat ${CLIENT_CERT} | base64 | tr -d '\n')
CLIENT_KEY_DATA=$(cat ${CLIENT_KEY} | base64 | tr -d '\n')

cat << EOF > ${KUBE_CONFIG}
apiVersion: v1
kind: Config
clusters:
- name: kubernetes
  cluster:
    certificate-authority-data: ${CA_DATA}
    server: https://192.168.43.101:6443
users:
- name: kubelet
  user:
    client-certificate-data: ${CLIENT_CERTS_DATA}
    client-key-data: ${CLIENT_KEY_DATA}
contexts:
- context:
    cluster: kubernetes
    user: kubelet
  name: kubelet-context
current-context: kubelet-context
EOF

mkdir -p ~vagrant/.kube
cp ${KUBE_CONFIG} ~vagrant/.kube/config
chown -R vagrant:vagrant ~vagrant/.kube
