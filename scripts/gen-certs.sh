#!/usr/bin/env bash

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

SERVER_SUBJECT="/CN=kube-apiserver"
SERVER_KEY="${KUBE_CERTS_DIR}/apiserver.key"
SERVER_CERT_REQ="${KUBE_CERTS_DIR}/apiserver.csr"
SERVER_CERT="${KUBE_CERTS_DIR}/apiserver.crt"
SERVER_CERT_CONF="${KUBE_CERTS_DIR}/apiserver.cnf"

SERVER_SANS="DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.local"
SERVER_SANS="${SERVER_SANS},IP:192.168.43.101"
SERVER_SANS="${SERVER_SANS},IP:127.0.0.1"

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

SUBJECT="/O=system:masters/CN=kubernetes-admin"
CLIENT_KEY=${KUBE_CERTS_DIR}/admin.key
CLIENT_CERT_REQ=${KUBE_CERTS_DIR}/admin.csr
CLIENT_CERT=${KUBE_CERTS_DIR}/admin.crt
CLIENT_CERT_CONF="${KUBE_CERTS_DIR}/admin.cnf"

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
            -subj "${SUBJECT}" \
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
