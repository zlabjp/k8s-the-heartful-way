#!/bin/bash

NAME=$1

echo "= Creating ${NAME} Pod..."
echo

PAUSE_CONTAINER=k8s_POD_default-${NAME}
echo "== Creating pause container..."
echo docker run -d \
    --network none \
    --name ${PAUSE_CONTAINER} \
    k8s.gcr.io/pause:3.1
docker run -d \
    --network none \
    --name ${PAUSE_CONTAINER} \
    k8s.gcr.io/pause:3.1

PID=$(docker inspect -f '{{ .State.Pid }}' ${PAUSE_CONTAINER})
NETNS=/proc/${PID}/ns/net

export CNI_PATH=/opt/cni/bin
export CNI_COMMAND=ADD
export CNI_CONTAINERID=${PAUSE_CONTAINER}
export CNI_NETNS=${NETNS}

export PATH=$CNI_PATH:$PATH
export POD_SUBNET=$(kubectl get node inajob -o jsonpath="{.spec.podCIDR}")

export CNI_IFNAME=eth0

echo "== Creating pod network device..."
echo export CNI_PATH=/opt/cni/bin
echo export CNI_COMMAND=ADD
echo export CNI_CONTAINERID=${PAUSE_CONTAINER}
echo export CNI_NETNS=${NETNS}
echo
echo export PATH=$PATH
echo export POD_SUBNET=${POD_SUBNET}
echo
echo export CNI_IFNAME=eth0

BRIDGE_OUTPUT=/tmp/bridge-output.txt
/opt/cni/bin/bridge <<EOF > ${BRIDGE_OUTPUT}
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cni0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_SUBNET}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

export CNI_IFNAME=lo
/opt/cni/bin/loopback <<EOF
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF

echo "Created:"
cat ${BRIDGE_OUTPUT}

POD_IP=$(jq -r '.ips[0].address' < ${BRIDGE_OUTPUT})
POD_IP=${POD_IP%/24}

docker run -d \
    --network container:${PAUSE_CONTAINER} \
    --name k8s_${NAME}_${NAME}_default \
    zlabjp/heartful-app:1

STATUS=$(cat <<EOF
{
  "status": {
    "conditions": [
      {
        "lastProbeTime": null,
        "lastTransitionTime": "$(date --utc +"%Y-%m-%dT%H:%M:%SZ")",
        "status": "True",
        "type": "Initialized"
      },
      {
        "lastProbeTime": null,
        "lastTransitionTime": "$(date --utc +"%Y-%m-%dT%H:%M:%SZ")",
        "status": "True",
        "type": "Ready"
      },
      {
        "lastProbeTime": null,
        "lastTransitionTime": "$(date --utc +"%Y-%m-%dT%H:%M:%SZ")",
        "status": "True",
        "type": "ContainersReady"
      }
    ],
    "containerStatuses": [
      {
        "containerID": "human://${NAME}-0001",
        "image": "zlabjp/heartful-app:1",
        "imageID": "docker-pullable://heartful-app@sha256:96fb261b66270b900ea5a2c17a26abbfabe95506e73c3a3c65869a6dbe83223a",
        "lastState": {},
        "name": "${NAME}",
        "ready": true,
        "restartCount": 0,
        "state": {
          "running": {
            "startedAt": "$(date --utc +"%Y-%m-%dT%H:%M:%SZ")"
          }
        }
      }
    ],
    "hostIP": "192.168.43.111",
    "phase": "Running",
    "podIP": "${POD_IP}",
    "startTime": "$(date --utc +"%Y-%m-%dT%H:%M:%SZ")"
  }
}
EOF
)

curl -k -X PATCH -H "Content-Type: application/strategic-merge-patch+json" \
    --key ~vagrant/secrets/user.key \
    --cert ~vagrant/secrets/user.crt \
    --data-binary "${STATUS}" "https://192.168.43.101:6443/api/v1/namespaces/default/pods/${NAME}/status"
