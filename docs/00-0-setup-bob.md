アリスより前にボブのノードをセットアップしておく必要がある。

## ネットワーク割り当て

```bash
ip route add 10.244.1.0/24 via 192.168.43.111 # Alice のマシン
```

## ボブの nginx コンテナ作成

### pause container

```bash
# TODO: labels
docker run -d \
    --network none \
    --name k8s_POD_default-nginx \
    k8s.gcr.io/pause:3.1
```

### nginx container

```bash
docker run -d \
    --network container:k8s_POD_default-nginx \
    --name k8s_nginx_nginx_default \
    nginx:1.14
```

### pod ip 割り当て

```bash
pid=$(docker inspect -f '{{ .State.Pid }}' k8s_POD_default-nginx)
netns=/proc/$pid/ns/net
export CNI_PATH=/opt/cni/bin
export CNI_COMMAND=ADD
export PATH=$CNI_PATH:$PATH
export CNI_CONTAINERID=k8s_POD_default-nginx
export CNI_NETNS=$netns

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
          [{"subnet": "10.244.2.0/24"}]
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
