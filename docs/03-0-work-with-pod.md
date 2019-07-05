# 稲津くんの初仕事

## スケジューラー @master01 node で作業

まず、ノードに割り当たっていないPodを取得します。

```bash
$ kubectl proxy &
```

```bash
$ SCHEDULER_NAME="human-scheduler"
```

`spec.schedulerName` が `human-scheduler` である、かつ `spec.nodeName` が `null` (ノードに割り当てられていない) Pods を取得する。

```bash
$ curl -s http://127.0.0.1:8001/api/v1/pods | jq -r --arg SCHEDULER_NAME "$SCHEDULER_NAME" '.items[] | select(.spec.schedulerName == $SCHEDULER_NAME) | select(.spec.nodeName == null) | .metadata.namespace+"/"+.metadata.name'
default/nginx
```

ノードを取得する。それじゃあ inajob くんにお願いしようかな！出勤してるようだし！

```
kubectl get node
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
$ curl -X POST -H "Content-Type: application/yaml" --data-binary @nginx-binding.yaml "http://127.0.0.1:8001/api/v1/namespaces/${NAMESPACE}/pods/${POD_NAME}/binding"
```

## Pod を割り当てられた稲津くん @inajob node で作業

StatusがPending、かつ自分に割り当てられたPodを見張ってます。kubectl を使うのか、`kubectl proxy` & `curl` で生リクエストを投げるかは作業者の好みです。

```
kubectl get pod --field-selector 'status.phase=Pending,spec.nodeName=inajob' -A
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

```
sudo su # 以降、root で作業
pid=$(docker inspect -f '{{ .State.Pid }}' k8s_POD_default-nginx)
netns=/proc/$pid/ns/net
```



