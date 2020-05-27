#!/usr/bin/env bash
# Copyright 2020 Z Lab Corporation. All rights reserved.
#
# For the full copyright and license information, please view the LICENSE
# file that was distributed with this source code.

set -eu
export LC_ALL=C

KUBE_ROOT="/vagrant/kubernetes"
KUBE_CERTS_DIR="${KUBE_ROOT}/secrets"

mkdir -p ${KUBE_CERTS_DIR}

CA_KEY=${KUBE_CERTS_DIR}/ca.key
CA_CERT=${KUBE_CERTS_DIR}/ca.crt
CA_SERIAL=${KUBE_CERTS_DIR}/ca.serial

if [[ ! -f ${CA_KEY} ]]; then
    openssl genrsa -out "${CA_KEY}" 4096
fi
openssl req -x509 -new -nodes \
            -key "${CA_KEY}" \
            -days 10000 \
            -out "${CA_CERT}" \
            -subj "/CN=kube-ca"

function gen_server_cert() {
    cat > ${SERVER_CERT_CONF} <<EOF
[req]
req_extensions      = v3_req
distinguished_name  = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints    = CA:FALSE
keyUsage            = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage    = clientAuth, serverAuth
subjectAltName      = ${SERVER_SANS}
EOF

    if [[ ! -f ${SERVER_KEY} ]]; then
        openssl genrsa -out "${SERVER_KEY}" 4096
    fi

    openssl req -new -key "${SERVER_KEY}" \
                -out "${SERVER_CERT_REQ}" \
                -subj "${SERVER_SUBJECT}" \
                -config ${SERVER_CERT_CONF}

    openssl x509 -req -in "${SERVER_CERT_REQ}" \
                -CA "${CA_CERT}" \
                -CAkey "${CA_KEY}" \
                -CAcreateserial \
                -CAserial "${CA_SERIAL}" \
                -out "${SERVER_CERT}" \
                -days 365 \
                -extensions v3_req \
                -extfile ${SERVER_CERT_CONF}
}

function gen_client_cert() {
    cat > ${CLIENT_CERT_CONF} <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF

    if [[ ! -f ${CLIENT_KEY} ]]; then
        openssl genrsa -out "${CLIENT_KEY}" 4096
    fi

    openssl req -new -key "${CLIENT_KEY}" \
                -out "${CLIENT_CERT_REQ}" \
                -subj "${CLIENT_SUBJECT}" \
                -config ${CLIENT_CERT_CONF}

    openssl x509 -req -in "${CLIENT_CERT_REQ}" \
                -CA "${CA_CERT}" \
                -CAkey "${CA_KEY}" \
                -CAcreateserial \
                -CAserial "${CA_SERIAL}" \
                -out "${CLIENT_CERT}" \
                -days 365 \
                -extensions v3_req \
                -extfile ${CLIENT_CERT_CONF}
}

SERVER_SUBJECT="/CN=kube-apiserver"
SERVER_KEY="${KUBE_CERTS_DIR}/apiserver.key"
SERVER_CERT_REQ="${KUBE_CERTS_DIR}/apiserver.csr"
SERVER_CERT="${KUBE_CERTS_DIR}/apiserver.crt"
SERVER_CERT_CONF="${KUBE_CERTS_DIR}/apiserver.cnf"

SERVER_SANS="DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.local"
SERVER_SANS="${SERVER_SANS},IP:192.168.43.101"
SERVER_SANS="${SERVER_SANS},IP:127.0.0.1"

gen_server_cert

CLIENT_SUBJECT="/O=system:masters/CN=kubernetes-admin"
CLIENT_KEY=${KUBE_CERTS_DIR}/admin.key
CLIENT_CERT_REQ=${KUBE_CERTS_DIR}/admin.csr
CLIENT_CERT=${KUBE_CERTS_DIR}/admin.crt
CLIENT_CERT_CONF="${KUBE_CERTS_DIR}/admin.cnf"

gen_client_cert

CLIENT_SUBJECT="/O=system:masters/CN=kubelet-client"
CLIENT_KEY=${KUBE_CERTS_DIR}/kubelet-client.key
CLIENT_CERT_REQ=${KUBE_CERTS_DIR}/kubelet-client.csr
CLIENT_CERT=${KUBE_CERTS_DIR}/kubelet-client.crt
CLIENT_CERT_CONF="${KUBE_CERTS_DIR}/kubelet-client.cnf"

gen_client_cert

SERVER_SUBJECT="/CN=yuanying"
SERVER_KEY="${KUBE_CERTS_DIR}/kubelet-yuanying.key"
SERVER_CERT_REQ="${KUBE_CERTS_DIR}/kubelet-yuanying.csr"
SERVER_CERT="${KUBE_CERTS_DIR}/kubelet-yuanying.crt"
SERVER_CERT_CONF="${KUBE_CERTS_DIR}/kubelet-yuanying.cnf"

SERVER_SANS="DNS:yuanying"
SERVER_SANS="${SERVER_SANS},IP:192.168.43.112"
SERVER_SANS="${SERVER_SANS},IP:127.0.0.1"

gen_server_cert

SERVER_SUBJECT="/CN=inajob"
SERVER_KEY="${KUBE_CERTS_DIR}/kubelet-inajob.key"
SERVER_CERT_REQ="${KUBE_CERTS_DIR}/kubelet-inajob.csr"
SERVER_CERT="${KUBE_CERTS_DIR}/kubelet-inajob.crt"
SERVER_CERT_CONF="${KUBE_CERTS_DIR}/kubelet-inajob.cnf"

SERVER_SANS="DNS:inajob"
SERVER_SANS="${SERVER_SANS},IP:192.168.43.111"
SERVER_SANS="${SERVER_SANS},IP:127.0.0.1"

gen_server_cert
