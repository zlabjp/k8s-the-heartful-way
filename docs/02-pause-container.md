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
export CNI_IFNAME=eth0

/opt/cni/bin/bridge <<EOF
{
    "name": "mynet",
    "type": "bridge",
    "bridge": "cni0",
    "isDefaultGateway": true,
    "forceAddress": false,
    "ipMasq": true,
    "hairpinMode": true,
    "ipam": {
        "type": "host-local",
        "subnet": "10.244.1.0/24",
        "routes": [
            { "dst": "10.244.0.0/16" }
        ]
    }
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

docker run -d \
    --network container:k8s_POD_default-nginx \
    --name test \
    busybox \
    sleep 10000
    