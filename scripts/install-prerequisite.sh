#!/usr/bin/env bash

set -eu
export LC_ALL=C

echo "Start to wait for Kubernetes API (https://192.168.43.101:6443/healthz)"
until curl -skf "https://192.168.43.101:6443/healthz"
do
    echo "Still waiting for Kubernetes API..."
    sleep 5
done

export KUBECONFIG=/etc/kubernetes/admin.yaml

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
        --key /etc/kubernetes/secrets/admin.key \
        --cert /etc/kubernetes/secrets/admin.crt \
        --data-binary "${STATUS}" "https://127.0.0.1:6443/api/v1/nodes/${m}/status"
done

STATUS=${READY}
STATUS=$(echo ${STATUS} | sed -e "s/ADDRESS/192.168.43.112/")
curl -k -X PATCH -H "Content-Type: application/strategic-merge-patch+json" \
    --key /etc/kubernetes/secrets/admin.key \
    --cert /etc/kubernetes/secrets/admin.crt \
    --data-binary "${STATUS}" "https://127.0.0.1:6443/api/v1/nodes/yuanying/status"

cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: default-token
  namespace: default
  annotations:
    kubernetes.io/service-account.name: default
data:
  ca.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUM1ekNDQWMrZ0F3SUJBZ0lCQVRBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwdGFXNXAKYTNWaVpVTkJNQjRYRFRFNE1Ea3dOVEExTXpRek1Wb1hEVEk0TURrd016QTFNelF6TVZvd0ZURVRNQkVHQTFVRQpBeE1LYldsdWFXdDFZbVZEUVRDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTUt6Cnc4RmExNE1nYVRTTlhZUzFTRjJvTTVOc3BJdUIycUw4ZDlnM0NMQ3pxVTlQSXpjOExlS1h5aG1mUE5LK0RhdUgKSWprTjdiY3loSnFyK0dMd29pTXU1K2dpaHBadkJ3MXJpYkVTVndMQVpEQTRXL2ZQZlRIdG5CZU5BY29FUURPQQppdWhCRkRXVkVoenlWdVhCSmxHMG4yV2dtbUM4dVM1dndQUFk2bDFZOG5RMFVZWkU4eXhBMm9pNi9UcURqREpSCmZMcE9OZkhFQzk1SzRDN3NhWUxEZDdjVDNnb1lhYmlOa25qeHNIUDhrM2l0UXlxa0xVNXQvTGY1TTZUdExsQjEKVURaSjBrSEZaRm9uZnhwKzJCVGFOUXgyUkxBZ3g1ZlFzcVVhNTVNNGcvREY4d3RPK3lCTGtZMW5DdWgvV3dGTQorTGkxU3kxSU1EeVRmdG4xNHhVQ0F3RUFBYU5DTUVBd0RnWURWUjBQQVFIL0JBUURBZ0trTUIwR0ExVWRKUVFXCk1CUUdDQ3NHQVFVRkJ3TUNCZ2dyQmdFRkJRY0RBVEFQQmdOVkhSTUJBZjhFQlRBREFRSC9NQTBHQ1NxR1NJYjMKRFFFQkN3VUFBNElCQVFBRU9vQWhrbVFSZkkwVm9SZGY4eGFmSkxnVGY0TnZTYWpCT0x3STZZMitFZjVjT3hoOQp6N0orSmRncVA5NWMrbTlSZWxrVjVyazRGU2Z6RWR3RVZTcU91bGJBT2d2aUlaQTkyVVZrOUVDTmxNY1NVcy84CktqZnJKcVpMQ1ZHVTluY3p1V2hkbGJJZHN1dEY2dnhoT0paMmptZXNuY0RiOGFudEN6cnZxT01DRUxYME1kQW4KRGVSdVMwUUpBNk9PSkQwVUJBQ09lY281Y1MvZzFlWG5HbVJuMEs3VkJjNjIyazV2TXRVdGVJR28xV3ZMYlVUdApFZ0tBbVZkak44d1M4ei9FT2xjd3RIOFBJaUFtRDVwaVEwSkFxcUl6WXQwWVhBUzBBb2lVQTcrWEp0UzhTVXlWCnArcHNSKytkQmcyYW1VTndxRzViT0J3NTduVE42TWNHcm9UUQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
  namespace: ZGVmYXVsdA==
  token: ZXlKaGJHY2lPaUpTVXpJMU5pSXNJbXRwWkNJNklpSjkuZXlKcGMzTWlPaUpyZFdKbGNtNWxkR1Z6TDNObGNuWnBZMlZoWTJOdmRXNTBJaXdpYTNWaVpYSnVaWFJsY3k1cGJ5OXpaWEoyYVdObFlXTmpiM1Z1ZEM5dVlXMWxjM0JoWTJVaU9pSmtaV1poZFd4MElpd2lhM1ZpWlhKdVpYUmxjeTVwYnk5elpYSjJhV05sWVdOamIzVnVkQzl6WldOeVpYUXVibUZ0WlNJNkltUmxabUYxYkhRdGRHOXJaVzR0YW5Cb2RtZ2lMQ0pyZFdKbGNtNWxkR1Z6TG1sdkwzTmxjblpwWTJWaFkyTnZkVzUwTDNObGNuWnBZMlV0WVdOamIzVnVkQzV1WVcxbElqb2laR1ZtWVhWc2RDSXNJbXQxWW1WeWJtVjBaWE11YVc4dmMyVnlkbWxqWldGalkyOTFiblF2YzJWeWRtbGpaUzFoWTJOdmRXNTBMblZwWkNJNklqVTFNVGN6WlRNeExXTmtaVEF0TVRGbE9DMWhPVGMwTFRBNE1EQXlOelpsT1RnM05TSXNJbk4xWWlJNkluTjVjM1JsYlRwelpYSjJhV05sWVdOamIzVnVkRHBrWldaaGRXeDBPbVJsWm1GMWJIUWlmUS5ZY05uUlNNX1hkQmFVUlZneUt3WXEwYVZ0bmJJSDRJSkNGb2JlM1JjNEp2cHZXanVLbXpzZzZ3cGxYUFlZR1d6Y2ZKVkxreVJ0RnRwZWhVVnQ3Qk5leFltY04wN1hSV3o5U1oyaUctcDAyd0NYR0tZUDhWc3Q2a0poWjJwaVhmTzZKR0Nhd2lEWjExM0o5Z1FFZmdVeFkwNG55eDRyektuY1dUd05tUGVGTmg3elVlZS16RlNQS3FlVHl1UzJ3OW5GNlZrOVprT0FFUS1RajJRWFZrSmlxM3J6UElMWm16NDduMFBUcUVPbHZkUWlzcS1zR0pmWVFzZmdGbk5xYlk1UndYT1BYdzNRa0dvWHpUOFQ2bmQ1UzJxX3pGSVJicHl5dXRVUVRMWU9rMV9FaWZLWHVDd2pNQXFpWVI3WHdmQ3Q3MTlIWE10WUJMbnZxaVV3R2FCd3c=
type: kubernetes.io/service-account-token
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
  namespace: default
secrets:
- name: default-token
---
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: kuard
spec:
  replicas: 2
  selector:
    matchLabels:
      app: kuard
  template:
    metadata:
      labels:
        app: kuard
    spec:
      containers:
        - name: kuard
          image: "gcr.io/kuar-demo/kuard-amd64:2"
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  schedulerName: human-scheduler
  containers:
  - image: nginx:1.14
    name: nginx
EOF
