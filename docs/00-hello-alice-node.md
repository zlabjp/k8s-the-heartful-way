# [WIP] Alice がノードとして登録された時にすること

Alice が Z lab に採用されました！
彼女は新しく kubelet として働くことになっています。
そんな彼女がまず最初にしなければいけないことは、自分に割り当てられたノードのセットアップです。

-   docker のインストール
-   cni のインストール
-   csi のインストール？

## ネットワークの設定

Z lab で利用されている Pod のネットワークは、`10.244.0.0/16` です。
その中でも彼女に特に割り当てられているネットワークは `10.244.1.0/24` です。
同僚の Bob は `10.244.2.0/24` だそうです。

取り急ぎ彼女は Bob と仕事を始める必要があるそうです。
さあ、ネットワークの準備を始めましょう！

### 自分のマシンにコンテナのネットワークを作る

```bash
ip route add 10.244.2.0/24 via 192.168.43.112 # Bob のマシン
```

以上！

### 以下メモ

```bash
contid=test-container
netns=/var/run/netns/$contid
ip netns add $contid

export CNI_PATH=/opt/cni/bin
export CNI_COMMAND=ADD
export PATH=$CNI_PATH:$PATH
export CNI_CONTAINERID=$contid
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
          [{"subnet": "10.244.1.0/24"}]
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