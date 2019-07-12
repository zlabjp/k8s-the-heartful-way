# 稲津くんの初仕事

## スケジューラー @master01 node で作業

まず、ノードに割り当たっていないPodを取得します。

```bash
$ SCHEDULER_NAME="human-scheduler"
```

`spec.schedulerName` が `human-scheduler` である、かつ `spec.nodeName` が `null` (ノードに割り当てられていない) Pods を取得する。

```bash
$ curl -s -k https://192.168.43.101:6443/api/v1/pods \
  --key /vagrant/kubernetes/secrets/admin.key \
  --cert /vagrant/kubernetes/secrets/admin.crt | \
  jq -r --arg SCHEDULER_NAME "$SCHEDULER_NAME" '.items[] | select(.spec.schedulerName == $SCHEDULER_NAME) | select(.spec.nodeName == null) | .metadata.namespace+"/"+.metadata.name'
default/nginx
```

ノードを取得する。

```bash
kubectl get node | grep --color -E "^|inajob.+$"
```

それじゃあ inajob くんにお願いしようかな！出勤してるようだし！

```bash
kubectl describe node inajob | head -n 14
```

`inajob` node に `nginx` Pod をアサインする。

```bash
$ NAMESPACE="default" POD_NAME="nginx" NODE_NAME="inajob"
$ cat <<EOL | tee nginx-binding.yaml
apiVersion: v1
kind: Binding
metadata:
  name: $POD_NAME
target:
  apiVersion: v1
  kind: Node
  name: $NODE_NAME
EOL
$ curl -k -X POST -H "Content-Type: application/yaml" \
  --data-binary @nginx-binding.yaml \
  --key /vagrant/kubernetes/secrets/admin.key \
  --cert /vagrant/kubernetes/secrets/admin.crt \
  "https://192.168.43.101:6443/api/v1/namespaces/${NAMESPACE}/pods/${POD_NAME}/binding"
```

アサインされました。

```
kubectl get pod -o wide | grep --color -E "^|inajob"
```

## Pod を割り当てられた稲津くん @inajob node で作業

StatusがPending、かつ自分に割り当てられたPodを見張ってます。kubectl を使うのか、`kubectl proxy` & `curl` で生リクエストを投げるかは作業者の好みです。

```
kubectl get pod \
  --field-selector 'status.phase=Pending,spec.nodeName=inajob' -A
```

nginx が割り当てられてることが確認できました。
それでは Pod を起動しましょう。

Pod とは？コンテナを束ねたもの。ネットワークネームスペースを共有。
コンテナランタイムがdocker の場合はまず、コンテナを束ねるためのコンテナを起動します。
普通は、pause コンテナーと呼ばれるものです。

```bash
# TODO: labels
docker run -d \
    --network none \
    --name k8s_POD_default-nginx \
    k8s.gcr.io/pause:3.1
```

### Pod ネットワークの設定 (Pod に IPアドレスを割り当てよう！)

通常、Podの中のコンテナ同士はlocalhostで通信できます。これはnetwork namespaceを共有しているからなのですが、このnetwork namespaceが普通、どこに作られれているのかというと、この pause コンテナに紐づけられます。

まず、先ほど作った pause コンテナの network namespace を取得します。

```bash
sudo su # 以降、root で作業
PID=$(docker inspect -f '{{ .State.Pid }}' k8s_POD_default-nginx)
NETNS=/proc/${PID}/ns/net
```

そして、その network namespace に、CNI のブリッジプラグインを使って IP アドレスを付与してあげます。
CNI は環境変数と標準入力を入力としてバイナリを実行してあげれば良いだけなので手作業にぴったりですね！

まず、CNI でインタフェースを作成するのに必要となる環境変数を設定します。 `CNI_COMMAND=ADD` で、CNIに対してインタフェースを作成する、という指示をすることができます。

```bash
export CNI_PATH=/opt/cni/bin
export CNI_COMMAND=ADD
export CNI_CONTAINERID=k8s_POD_default-nginx
export CNI_NETNS=${NETNS}
export CNI_IFNAME=eth0
```

そして、CNI の bridge プラグインを実行します。

```bash
export PATH=$CNI_PATH:$PATH
export POD_SUBNET=$(kubectl get node inajob -o jsonpath="{.spec.podCIDR}")

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
```

結果の JSON に Pod の IP が含まれています。

最後に、loopback デバイスを追加してやります。インタフェースの名前以外の環境変数は共通なので使い回しています。

```bash
export CNI_IFNAME=lo
/opt/cni/bin/loopback <<EOF
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF
```

root での作業が終了したので、一般ユーザに戻ります。

```bash
exit # rootの作業終了
```

(多分、10.244.1.2 がアサインされてる。違ったら以下のアドレスを読み換える。)

ちゃんとアドレスが付与されました、ping して試してみましょう！

```
# POD_IP の環境変数は以降で利用するのでちゃんと設定しておくこと。
POD_IP=10.244.1.2
ping ${POD_IP}
```

ちゃんと返ってきましたね！

### nginx コンテナの起動

それでは、そもそもの nginx コンテナを起動します。
ネットワークに先ほど作った pause コンテナを指定してあげることで、
Pod の IP アドレスを利用することができるようになります。

```bash
docker run -d \
    --network container:k8s_POD_default-nginx \
    --name k8s_nginx_nginx_default \
    nginx:1.14
```

### Pod status を更新

無事、Pod が起動しました。ちゃんとPodが起動できたことをapiserverに登録してみんなに知らせましょう。
この場合は Pod の status を更新すれば ok です。

本来は各 Phase ごとにちゃんとステータスを変更しなければならないと社則で決まっているのですが、
稲津くんは少し手を抜いたようですね。

```bash
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
        "containerID": "human://nginx-0001",
        "image": "nginx:1.14",
        "imageID": "docker-pullable://nginx@sha256:96fb261b66270b900ea5a2c17a26abbfabe95506e73c3a3c65869a6dbe83223a",
        "lastState": {},
        "name": "nginx",
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
```


```bash
curl -k -X PATCH -H "Content-Type: application/strategic-merge-patch+json" \
    --key ~vagrant/secrets/user.key \
    --cert ~vagrant/secrets/user.crt \
    --data-binary "${STATUS}" "https://192.168.43.101:6443/api/v1/namespaces/default/pods/nginx/status"
```

Pod が無事、ノードに登録されて実行されました！！

```bash
kubectl get pods -o wide | grep --color -E "^|Running"
```
