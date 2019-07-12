# 稲津くんの出社

必要なツールはインストールしてあるから、設定しておいてねと言われる。
(以下の説明は全て須田さんがやって、稲津さんは作業だけをする感じ？)

1.  ネットワークの設定
2.  ノードを登録

## ネットワークの設定 @inajob node で作業

### Pod network の設定

TODO: スライドが欲しい。

-   X社ではトラディショナルな Pod ネットワークを採用している。
-   各ノードごとにPodネットワークのCIDRが割り当てられており、ノードを跨いだPod間の通信はノード上のルーティングテーブルによってパケットの行き先が解決される。
-   X社で利用されている Pod のネットワークは、`10.244.0.0/16` です。
-   その中でも、稲津くんに割り当てられているネットワークは `10.244.1.0/24` です。
-   稲津くんは先輩達のノードをルーティングテーブルに加える必要がある。
-   とりあえず稲津くんは yuanying のノードをルーティングテーブルに追加する。
-   yuanying に割り当てられているネットワークは `10.244.2.0/24` です。

yuanying に割り当てられている Pod のネットワークは以下のコマンドで取得できます。

```
kubectl get node yuanying -o jsonpath="{.spec.podCIDR}"
```

yuanying のノードのアドレスは以下のコマンドで取得できます。

```
kubectl get node yuanying -o jsonpath="{.status.addresses[0].address}"
```

取得したアドレスをルーティングテーブルに追加します。

```bash
cat <<EOF | sudo tee /etc/netplan/50-vagrant.yaml
---
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      addresses:
      - 192.168.43.111/24
      routes:
      - to: 10.244.2.0/24
        via: 192.168.43.112
EOF
sudo netplan apply
```

ルーティングテーブルを確認してみましょう。yuanyingが管理しているPodあてのパケットはyuanyingノードにルーティングされていることが確認できました。

```
ip route | grep --color -E "^|^10\.244\.2\.0.+$"
```

引き続き、他のメンバーのルーティングも追加する必要がありますが、とりあえず今日のところは、これで大丈夫そうです。

### Service network の設定

TODO: Service の説明がここで欲しいかも。

X社では Service を実現するのに IPVS を使っているので、その事前準備をする必要があります。
しかし、 IPVS 単体ではマスカレードやパケットフィルタリングを実現することができないので、
結局ちゃんと動作するように、iptables の設定をする必要があります。

#### カーネルモジュールの設定

IPVS が conntrack の dnat の情報を消してしまうので、それを残すために必要。

-   ref: [IPVS (LVS/NAT) とiptables DNAT targetの共存について調べた](https://ntoofu.github.io/blog/post/research-ipvs-and-dnat/)

```bash
echo 1 | sudo tee /proc/sys/net/ipv4/vs/conntrack
```

#### dummy interface の作成

```bash
sudo ip link add kube-ipvs0 type dummy
```

#### ipset の設定

iptables に service が増えるたびにルールを増やして行くのはアホらしいので、ipset を使います。
まずは事前に利用する set を追加しましょう。

> 今回は nodeport や loadbalancer を使わないので、それらに関連するセットはセットアップしない。

まずは、コンテナ内からの自身へのヘアピンパケットに対応するためのセットを追加します。

```bash
sudo ipset create KUBE-LOOP-BACK hash:ip,port,ip
```

次に、Service の IP である Cluster IP に対応するためのセットの追加です。
ここには、全てのService IP が入ることになります。

```bash
sudo ipset create KUBE-CLUSTER-IP hash:ip,port
```

#### iptables rule の作成

IPVS mode では dnat しかしないので、その他の filter や masquerade などを処理するために、一部 iptables を利用しているので、その設定を入れる。
このルールは固定で、iptable mode のようにこれ以上増えることはありません。

(今回のデモでは ClusterIP しか処理しないので、それに関連する iptables のルールを追加しています。)

```bash
sudo iptables -t nat -N KUBE-MARK-MASQ
sudo iptables -t nat -A KUBE-MARK-MASQ -j MARK --set-xmark 0x4000/0x4000

sudo iptables -t nat -N KUBE-POSTROUTING
# kubernetes service traffic requiring SNAT
sudo iptables -t nat -A KUBE-POSTROUTING -m comment --comment "kubernetes service traffic requiring SNAT" -m mark --mark 0x4000/0x4000 -j MASQUERADE
# Kubernetes endpoints dst ip:port, source ip for solving hairpin purpose
sudo iptables -t nat -A KUBE-POSTROUTING -m comment --comment "Kubernetes endpoints dst ip:port, source ip for solving hairpin purpose" -m set --match-set KUBE-LOOP-BACK dst,dst,src -j MASQUERADE

sudo iptables -t nat -N KUBE-SERVICES
# Kubernetes service cluster ip + port for masquerade purpose
sudo iptables -t nat -A KUBE-SERVICES ! -s 10.244.0.0/16 -m comment --comment "Kubernetes service cluster ip + port for masquerade purpose" -m set --match-set KUBE-CLUSTER-IP dst,dst -j KUBE-MARK-MASQ
sudo iptables -t nat -A KUBE-SERVICES -m set --match-set KUBE-CLUSTER-IP dst,dst -j ACCEPT

# kubernetes service portals
sudo iptables -t nat -I PREROUTING -m comment --comment "kubernetes service portals" -j KUBE-SERVICES
sudo iptables -t nat -I OUTPUT -m comment --comment "kubernetes service portals" -j KUBE-SERVICES

# kubernetes postrouting rules
sudo iptables -t nat -I POSTROUTING -m comment --comment "kubernetes postrouting rules" -j KUBE-POSTROUTING

sudo iptables -t filter -N KUBE-FORWARD
# kubernetes forwarding rules
sudo iptables -t filter -A KUBE-FORWARD -m comment --comment "kubernetes forwarding rules" -m mark --mark 0x4000/0x4000 -j ACCEPT
# kubernetes forwarding conntrack pod source rule
sudo iptables -t filter -A KUBE-FORWARD -s 10.244.0.0/16 -m comment --comment "kubernetes forwarding conntrack pod source rule" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# kubernetes forwarding conntrack pod destination rule
sudo iptables -t filter -A KUBE-FORWARD -d 10.244.0.0/16 -m comment --comment "kubernetes forwarding conntrack pod destination rule" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# kubernetes forwarding rules
sudo iptables -t filter -I FORWARD -m comment --comment "kubernetes forwarding rules" -j KUBE-FORWARD
```

## ノードの登録 @inajob node で作業

セットアップが完了したので、自分のマシンをノードとして登録します。

X社の社員が管理しているノードは全て `kubectl` コマンドで確認することができます。

```
kubectl get node
```

ここに、自分のノードを追加します。

```
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: Node
metadata:
  name: inajob
  labels:
    node-role.kubernetes.io/newbie: ""
spec:
  podCIDR: 10.244.1.0/24
EOF
```

無事登録されたか確認してみましょう。

```
kubectl get nodes -o wide | grep --color -E "^|inajob.+$"
```

無事、**newbie** として登録されました。(STATUS NotReadyが目立ちますね。)

しかし、他の人と違って IP アドレスや OS イメージが unknown のままですね。
少なくともノードの IP アドレスを登録しておかないと他の人が困りそうです。

ノードのアドレスはノードオブジェクトの status に登録されています。
残念なことに status は `kubectl` を使って設定することができないので、
`curl` などの http を直接触ることができるツールを使って変更する必要があります。

status は以下のような json で表現できます。kubelet のバージョンや osImage を指定します。

```
STATUS=$(cat <<EOF
{
  "status": {
    "nodeInfo": {
      "kubeletVersion": "v1.15.0",
      "osImage": "Human 1.0.new",
      "kernelVersion": "4.15.2019-brain",
      "containerRuntimeVersion": "docker://18.6.3"
    },
    "addresses": [
      {
        "type": "InternalIP",
        "address": "192.168.43.111"
      }
    ]
  }
}
EOF
)
```

status はノードオブジェクトのサブリソースです。それを反映するには以下のエンドポイントを指定する必要があります。

```
curl -k -X PATCH -H "Content-Type: application/strategic-merge-patch+json" \
    --key ~vagrant/secrets/user.key \
    --cert ~vagrant/secrets/user.crt \
    --data-binary "${STATUS}" "https://192.168.43.101:6443/api/v1/nodes/inajob/status"
```

無事反映されました。

```
kubectl get nodes -o wide | grep --color -E "^|inajob.+$"
```

これで稲津くんの1日目の仕事は終わりです。
