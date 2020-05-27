#!/usr/bin/env bash

set -eu
export LC_ALL=C

cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: Node
metadata:
  name: inajob
spec:
  podCIDR: 10.244.1.0/24
EOF

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
      "kubeletVersion": "v1.18.2",
      "osImage": "Human 1.0.zlab",
      "kernelVersion": "4.15.YEAR-brain",
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

STATUS=${READY}
STATUS=$(echo ${STATUS} | sed -e "s/ADDRESS/192.168.43.111/")
curl -k -X PATCH -H "Content-Type: application/strategic-merge-patch+json" \
    --key /vagrant/kubernetes/secrets/admin.key \
    --cert /vagrant/kubernetes/secrets/admin.crt \
    --data-binary "${STATUS}" "https://127.0.0.1:6443/api/v1/nodes/inajob/status"
