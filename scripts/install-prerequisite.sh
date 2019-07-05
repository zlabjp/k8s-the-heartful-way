#!/usr/bin/env bash

set -eu
export LC_ALL=C

echo "Start to wait for Kubernetes API (https://192.168.43.101:6443/healthz)"
until curl -skf "https://192.168.43.101:6443/healthz"
do
    echo "Still waiting for Kubernetes API..."
    sleep 5
done

export KUBECONFIG=/vagrant/kubernetes/secrets/admin.yaml

kubectl apply -f /vagrant/resources/prerequisite/
MEMBERS="ainoya bhiro hatotaka hiyoshi kkohtaka ladicle mumoshu ryysud shmurata summerwind superbrothers takanariko takuhiro tatsuhiro-t tksm uesyn watawuwu ysakashita"

NOTREADY=$(cat <<EOF
{
  "status": {
    "conditions": [
      {
        "lastHeartbeatTime": "$(date --utc +"%Y-%m-%dT%H:%M:%SZ")",
        "message": "Taisya",
        "reason": "KubeletNotReady",
        "status": "False",
        "type": "Ready"
      }
    ],
    "nodeInfo": {
      "kubeletVersion": "v1.15.0",
      "osImage": "Human 1.0.zlab",
      "kernelVersion": "Brain-Z-2019",
      "containerRuntimeVersion": "docker://18.6.3"
    },
    "addresses": [
      {
        "type": "InternalIP",
        "address": "ADDRESS"
      }
    ]
  }
}
EOF
)
READY=$(cat <<EOF
{
  "status": {
    "conditions": [
      {
        "lastHeartbeatTime": "$(date --utc +"%Y-%m-%dT%H:%M:%SZ")",
        "message": "Starting work as a kubelet",
        "reason": "KubeletReady",
        "status": "True",
        "type": "Ready"
      }
    ],
    "nodeInfo": {
      "kubeletVersion": "v1.15.0",
      "osImage": "Human 1.0.zlab",
      "kernelVersion": "Brain-Z-2019",
      "containerRuntimeVersion": "docker://18.6.3"
    },
    "addresses": [
      {
        "type": "InternalIP",
        "address": "ADDRESS"
      }
    ]
  }
}
EOF
)

ADDRESS_SUFFIX=113
for m in $MEMBERS; do
    ADDRESS="192.168.43.${ADDRESS_SUFFIX}"
    if (( RANDOM % 2 )); then 
        STATUS=${READY}
    else
        STATUS=${NOTREADY}
    fi
    STATUS=$(echo ${STATUS} | sed -e "s/ADDRESS/${ADDRESS}/")
    ADDRESS_SUFFIX=$(expr ${ADDRESS_SUFFIX} + 1)
    echo ${STATUS}
    curl -k -X PATCH -H "Content-Type: application/strategic-merge-patch+json" \
        --key /vagrant/kubernetes/secrets/admin.key \
        --cert /vagrant/kubernetes/secrets/admin.crt \
        --data-binary "${STATUS}" "https://127.0.0.1:6443/api/v1/nodes/${m}/status"
done

STATUS=${READY}
STATUS=$(echo ${STATUS} | sed -e "s/ADDRESS/192.168.43.112/")
curl -k -X PATCH -H "Content-Type: application/strategic-merge-patch+json" \
    --key /vagrant/kubernetes/secrets/admin.key \
    --cert /vagrant/kubernetes/secrets/admin.crt \
    --data-binary "${STATUS}" "https://127.0.0.1:6443/api/v1/nodes/yuanying/status"
