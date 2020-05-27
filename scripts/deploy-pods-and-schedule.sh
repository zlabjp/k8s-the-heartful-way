#!/usr/bin/env bash

set -eu
export LC_ALL=C

kubectl get rs web -o json | \
    jq -r '.spec.template | .+{"apiVersion": "v1", "kind": "Pod"} | .metadata |= .+ {"name": "web-001"}' | \
    kubectl create -f -
kubectl get rs web -o json | \
    jq -r '.spec.template | .+{"apiVersion": "v1", "kind": "Pod"} | .metadata |= .+ {"name": "web-002"}' | \
    kubectl create -f -
kubectl get rs web -o json | \
    jq -r '.spec.template | .+{"apiVersion": "v1", "kind": "Pod"} | .metadata |= .+ {"name": "workspace"}' | \
    kubectl create -f -

NAMESPACE="default" POD_NAME="web-001" NODE_NAME="yuanying"

cat <<EOL | tee web-yuanying-binding.yaml
apiVersion: v1
kind: Binding
metadata:
  name: $POD_NAME
target:
  apiVersion: v1
  kind: Node
  name: $NODE_NAME
EOL
curl -k -X POST -H "Content-Type: application/yaml" \
  --data-binary @web-yuanying-binding.yaml \
  --key /vagrant/kubernetes/secrets/admin.key \
  --cert /vagrant/kubernetes/secrets/admin.crt \
  "https://192.168.43.101:6443/api/v1/namespaces/${NAMESPACE}/pods/${POD_NAME}/binding"

NAMESPACE="default" POD_NAME="web-002" NODE_NAME="inajob"
cat <<EOL | tee web-inajob-binding.yaml
apiVersion: v1
kind: Binding
metadata:
  name: $POD_NAME
target:
  apiVersion: v1
  kind: Node
  name: $NODE_NAME
EOL
curl -k -X POST -H "Content-Type: application/yaml" \
  --data-binary @web-inajob-binding.yaml \
  --key /vagrant/kubernetes/secrets/admin.key \
  --cert /vagrant/kubernetes/secrets/admin.crt \
  "https://192.168.43.101:6443/api/v1/namespaces/${NAMESPACE}/pods/${POD_NAME}/binding"

NAMESPACE="default" POD_NAME="workspace" NODE_NAME="inajob"
cat <<EOL | tee web-inajob-binding.yaml
apiVersion: v1
kind: Binding
metadata:
  name: $POD_NAME
target:
  apiVersion: v1
  kind: Node
  name: $NODE_NAME
EOL
curl -k -X POST -H "Content-Type: application/yaml" \
  --data-binary @web-inajob-binding.yaml \
  --key /vagrant/kubernetes/secrets/admin.key \
  --cert /vagrant/kubernetes/secrets/admin.crt \
  "https://192.168.43.101:6443/api/v1/namespaces/${NAMESPACE}/pods/${POD_NAME}/binding"

sleep 10

POD_IP1=$(kubectl get pod web-001 -o json | jq .status.podIP -r)
POD_IP2=$(kubectl get pod web-002 -o json | jq .status.podIP -r)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Endpoints
metadata:
  name: web-service
subsets:
- addresses:
  - ip: ${POD_IP1}
    nodeName: yuanying
  - ip: ${POD_IP2}
    nodeName: inajob
  ports:
  - port: 8080
    protocol: TCP
EOF
