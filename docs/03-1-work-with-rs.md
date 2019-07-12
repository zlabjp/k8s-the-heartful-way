# ReplicaSets を処理しよう！

## RS Controller @master01 node で作業

-   マネージャーも兼任してます、とかウンタラカンタラ。
-   ReplicaSet の説明。

状態が Desired とずれている ReplicaSet を取得します。

```bash
kubectl get replicasets -o wide -A | grep --color -E "^|DESIRED|CURRENT"
```

web という名前の ReplicaSets が Desired の状態とずれていることがわかりますね！
この RS は `app=web` という名前のラベルと関連づけられているようです。
それでは実際に条件に合う Pod が存在するか調べて見ましょう。

```bash
kubectl get pod -l app=web -A
```

ありませんね。そこで私、RS controllerという役職の出番です。
この役職の職務は、ReplicaSetsに定義されている分の Pod オブジェクトを作成することです。
ReplicaSet のテンプレート通りに書かれている分の Pod を作成します。

まず、ReplicaSet のテンプレートを抜き出して、kind と名前のフィールドを追加してやります。

```bash
kubectl get rs web -o json | \
    jq -r '.spec.template | .+{"apiVersion": "v1", "kind": "Pod"} | .metadata |= .+ {"name": "web-001"}'
```

このマニフェストを二回適用して、Pod を二個作ります。

```bash
kubectl get rs web -o json | \
    jq -r '.spec.template | .+{"apiVersion": "v1", "kind": "Pod"} | .metadata |= .+ {"name": "web-001"}' | \
    kubectl create -f -
kubectl get rs web -o json | \
    jq -r '.spec.template | .+{"apiVersion": "v1", "kind": "Pod"} | .metadata |= .+ {"name": "web-002"}' | \
    kubectl create -f -
```

Podを確認しみましょう。2個作られてますね！

```bash
kubectl get pod -l app=web
```

うまく作られたので ReplicaSet のstatus を更新しておきましょう。

```bash
STATUS=$(cat <<EOF
{
  "status": {
    "availableReplicas": 0,
    "fullyLabeledReplicas": 0,
    "observedGeneration": 1,
    "readyReplicas": 0,
    "replicas": 2
  }
}
EOF
)
```

```bash
curl -k -X PATCH -H "Content-Type: application/strategic-merge-patch+json" \
    --key /vagrant/kubernetes/secrets/admin.key \
    --cert /vagrant/kubernetes/secrets/admin.crt \
    --data-binary "${STATUS}" "https://192.168.43.101:6443/apis/apps/v1/namespaces/default/replicasets/web/status"
```

ReplicaSetのステータスを確認してみましょう。Current が無事、Desiredと一致しましたね！

```bash
kubectl get replicasets -o wide | grep --color -E "^|DESIRED|CURRENT"
```

さて、しかしこの状態は結局 Pod のオブジェクトが apiserver に登録されただけです。
この Pod を ready にするには？
そう、またもやスケジューラとkubeletさんの出番になるわけです。

## Scheduler @master01 node で作業

自分はスケジューラの役職を担っていますので、今作ったPodをスケジューリングしてあげる必要があります。
ノードに割り当たっていないPodを取得します。

```bash
$ SCHEDULER_NAME="human-scheduler"
```

```bash
$ curl -s -k https://192.168.43.101:6443/api/v1/pods \
  --key /vagrant/kubernetes/secrets/admin.key \
  --cert /vagrant/kubernetes/secrets/admin.crt | \
  jq -r --arg SCHEDULER_NAME "$SCHEDULER_NAME" '.items[] | select(.spec.schedulerName == $SCHEDULER_NAME) | select(.spec.nodeName == null) | .metadata.namespace+"/"+.metadata.name'
```

先ほど作った Pod が二つ表示されましたね。では、それぞれをノードに割り当てましょう。

```bash
kubectl get node | grep --color -E "^|^yuanying.*$"
```

それじゃあ、ちょうどリモートワークしてる yuanying くんに一つ目の Pod を担当してもらいましょうか。
X社は自由にリモートワークできる組織ですので、もちろんkubeletもリモートで担当することができます。

```bash
$ NAMESPACE="default" POD_NAME="web-001" NODE_NAME="yuanying"
$ cat <<EOL | tee web-yuanying-binding.yaml
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
  --data-binary @web-yuanying-binding.yaml \
  --key /vagrant/kubernetes/secrets/admin.key \
  --cert /vagrant/kubernetes/secrets/admin.crt \
  "https://192.168.43.101:6443/api/v1/namespaces/${NAMESPACE}/pods/${POD_NAME}/binding"
```

さて、リモートから作業してる yuanying くんはちゃんと Pod を作ってくれるかな？

```bash
kubectl get pod -o wide -w
```

できたようです。リモートなのにちゃんと仕事してますね！
本当はこの場所で一緒にプレゼンする予定だったのですが何故かリモートなんですね。なんででしょう？

まあ、気にせずにちゃんと アプリケーション が反応するか確認してみます。

```
kubectl get pod web-001 -o json | \
  jq -r ".status.podIP" | \
  xargs -I{} curl -v {}:8080
```

それでは二つ目の Pod はまた、新人の inajob くんに割り当てます。

```bash
NAMESPACE="default" POD_NAME="web-002" NODE_NAME="inajob"
cat <<EOL | tee web-inajob-binding.yaml
apiVersion: v1
kind: Binding
metadata:
  name: $POD_NAME
target:
  apiVersion: v1
  kind: Node
  name: $NODE_NAME
EOL
curl -k -X POST -H "Content-Type: application/yaml" \
  --data-binary @web-inajob-binding.yaml \
  --key /vagrant/kubernetes/secrets/admin.key \
  --cert /vagrant/kubernetes/secrets/admin.crt \
  "https://192.168.43.101:6443/api/v1/namespaces/${NAMESPACE}/pods/${POD_NAME}/binding"
```

## Pod を割り当てられた稲津くん @inajob node で作業

おやおや、inajob くん、さすが優秀です。作業をすでにスクリプト化して自動化してるようですね！

```bash
kubectl get pod \
  --field-selector 'status.phase=Pending,spec.nodeName=inajob' -A
```

自分に割り当てられたPodが増えたことを確認すると、スクリプトを実行しました。

```bash
sudo su
bash /vagrant/scripts/create-pod.sh web-002
```

Pod ができたようです。

## RS Controller @master01 node で作業

さて、RS Controller としてはマネージャーとして、指示した RS に対応する Pod がちゃんとできているかチェックしないとなりません。

```bash
kubectl get pod -l app=web -o wide | \
  grep --color -E "^|Running"
```

二つの Pod が Ready になっているようですね！
それでは RS 自体もちゃんと現状をアップデートしてあげましょう。

```bash
STATUS=$(cat <<EOF
{
  "status": {
    "availableReplicas": 2,
    "fullyLabeledReplicas": 2,
    "observedGeneration": 1,
    "readyReplicas": 2,
    "replicas": 2
  }
}
EOF
)
```

```bash
curl -k -X PATCH -H "Content-Type: application/strategic-merge-patch+json" \
    --key /vagrant/kubernetes/secrets/admin.key \
    --cert /vagrant/kubernetes/secrets/admin.crt \
    --data-binary "${STATUS}" "https://192.168.43.101:6443/apis/apps/v1/namespaces/default/replicasets/web/status"
```

Desired, Current, Ready が一致しました。これで RS の仕事はひとまず終了です。

```
kubectl get rs | grep --color -E "^|DESIRED|CURRENT|READY"
```

## Memo

Status の意味。

```
status:
  availableReplicas: 2
  fullyLabeledReplicas: 2
  observedGeneration: 1
  readyReplicas: 2
  replicas: 2
```

-   readyReplicas
    -   podutil.IsPodReady(pod) が true になった pod をカウント。
-   availableReplicas
    -   podutil.IsPodReady(pod) && podutil.IsPodAvailable(pod, rs.Spec.MinReadySeconds, metav1.Now()) が true になった pod をカウント。
-   fullyLabeledReplicas
    -   templateLabel.Matches(labels.Set(pod.Labels)) が true になった pod をカウント。

### IsPodAvailable とは？

> // IsPodAvailable returns true if a pod is available; false otherwise.
> // Precondition for an available pod is that it must be ready. On top
> // of that, there are two cases when a pod can be considered available:
> // 1. minReadySeconds == 0, or
> // 2. LastTransitionTime (is set) + minReadySeconds < current time
