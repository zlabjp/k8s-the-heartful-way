# ノードに pod が割り当てられたので pause コンテナー作成します

## pause コンテナ起動

```bash
# TODO: labels
docker run -d \
    --network none \
    --name k8s_POD_default-nginx \
    k8s.gcr.io/pause:3.1
```

## コンテナネットワークへ参加

```bash
sudo su

pid=$(docker inspect -f '{{ .State.Pid }}' k8s_POD_default-nginx)
netns=/proc/$pid/ns/net
export CNI_PATH=/opt/cni/bin
export CNI_COMMAND=ADD
export PATH=$CNI_PATH:$PATH
export CNI_CONTAINERID=k8s_POD_default-nginx
export CNI_NETNS=$netns
export POD_SUBNET=$(kubectl get node alice -o jsonpath="{.spec.podCIDR}")

export CNI_IFNAME=eth0
/opt/cni/bin/bridge <<EOF
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
```

## nginx 起動

```bash
docker run -d \
    --network container:k8s_POD_default-nginx \
    --name k8s_nginx_nginx_default \
    nginx:1.14
```

```
docker run -d \
    --network container:k8s_POD_default-nginx \
    --name test \
    busybox \
    sleep 10000
```