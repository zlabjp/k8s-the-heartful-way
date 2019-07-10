# Service を処理しよう！

-   スライドで、Service の説明が必要。

## Endpoint Controller @master01 node で作業

Pod が二つできたけど、それぞれのIPに直接アクセスするのは不便。
VIPなものがあっていい感じにロードバランシングして欲しい。それがServiceオブジェクト。
まとめてほしい Pod をラベルセレクターで指定してやる。

マネージャーの私はユーザが Service を作るのを待って、それを承認して、下々に作業を任せる。

```bash
kubectl get service -o wide
```

`web-service` という名前の Service が確認できます。
Selector から先ほど作った ReplicaSet をまとめる Service であることが伺えます。

```bash
kubectl get service web-service -o yaml
```

これを見るだけですと、10.254.10.128 という VIP で Service を作って欲しいということがわかるだけで、
実際にどの IP アドレスがこの Service に紐づいているのかわかりません。
そこで、私はコントローラマネージャの責務として、
ラベルで関連づいているPodからそのIPアドレスをこのサービスのEndpointとして登録する、ということをやってあげます。

まず、ラベルに関連するPodとそのIPアドレスを取得します。

```
kubectl get pod -l app=web -o wide
```

そして、このアドレスをもとに Endpoint オブジェクトを作成します。

```bash
POD_IP1=10.244.2.2
POD_IP2=10.244.1.3
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Endpoints
metadata:
  name: web-service
subsets:
- addresses:
  - ip: ${POD_IP1}
    nodeName: yuanying
  - ip: ${POD_IP2}
    nodeName: inajob
  ports:
  - port: 8080
    protocol: TCP
EOF
```

## kube-proxy としての稲津くん @inajob node で作業

さて、EndpointとServiceはあるけども、実際にそれらのPodにアクセスしなくちゃいけないのは作業者である稲津くんです。
稲津くんは管理者が作った EndpointとServiceの情報を利用して、自分のノードからそれらのServiceに接続できるように設定する必要があります。
これらの設定を行う役割は kube-proxy と呼ばれているようです。

稲津くんはこの設定に IPVS を使っているようです。`ipvsadm` を使うためにrootになります。

```
sudo su
```

それではまず、IPVS の Virtual Server を設定しましょう。 Virtual Server の VIP は service のアドレスとなります。

```
kubectl get services
```

サービスのアドレスが `10.254.10.128:80` であることがわかりました。それでは Virtual Server を設定しましょう。

```
ipvsadm -A -t 10.254.10.128:80 -s rr
```

次に、この Virtual Server に紐づく Real Server を設定します。この場合の Real Server はもちろん Pod なのですが、Kubernetes では Endpoint から作成することになっています。
Endpoint から作成することで外部のサービスを利用することができるなど、色々な柔軟性を得ることができるのですが、今回のデモでは時間がないので説明は省きます。

```
kubectl get endpoints 
```

Endpoint に設定されている二つのアドレスから Real Server を作ります。

```bash
POD_IP1=10.244.2.2
POD_IP2=10.244.1.3
ipvsadm -a -t 10.254.10.128:80 -r ${POD_IP1}:8080 -m
ipvsadm -a -t 10.254.10.128:80 -r ${POD_IP2}:8080 -m
```

さて、ちゃんと設定できたでしょうか？確認しましょう。

```bash
ipvsadm -Ln
```

VIP に対して curl コマンドを実行してみます。

```bash
curl 10.254.10.128
```

## ありそうな質問

-   Q: なんで Pod から直接じゃなくて、Endpointから kube-proxy はリアルサーバを作成するのか？
