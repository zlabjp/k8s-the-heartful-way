# 稲津くんの出社

必要なツールはインストールしてあるから、設定しておいてねと言われる。
(以下の説明は全て須田さんがやって、稲津さんは作業だけをする感じ？)

1.  ネットワークの設定
2.  ノードを登録

## ネットワークの設定 @inajob node で作業

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
```
sudo ip route add 10.244.2.0/24 via 192.168.43.112
```

ルーティングテーブルを確認してみましょう。yuanyingが管理しているPodあてのパケットはyuanyingノードにルーティングされていることが確認できました。

```
ip route | grep --color -E "^|^10\.244\.2\.0.+$"
```

引き続き、他のメンバーのルーティングも追加する必要がありますが、とりあえず今日のところは、これで大丈夫そうです。

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
      "osImage": "Human 1.0.zlab.new",
      "kernelVersion": "Brain-Z-2019",
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
