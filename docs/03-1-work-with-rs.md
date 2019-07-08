# ReplicaSets を処理しよう！

## RS Controller @master01 node で作業

-   マネージャーも兼任してます、とかウンタラカンタラ。
-   ReplicaSet の説明。

状態が Desired とずれている ReplicaSet を取得します。

```bash
kubectl get replicasets -o wide
```

web という名前の ReplicaSets が Desired の状態とずれていることがわかりますね！
この RS は `app=web` という名前のラベルと関連づけられているようです。
それでは実際に条件に合う Pod が存在するか調べて見ましょう。

```bash
kubectl get pod -l app=web
```

ありませんね。そこで私、RS controllerという役職の出番です。
この役職の職務は、ReplicaSetsに定義されている分の Pod オブジェクトを作成することです。
ReplicaSet のテンプレート通りに書かれている分の Pod を作成します。

まず、ReplicaSet のテンプレートを抜き出して、kind と名前のフィールドを追加してやります。

```bash
kubectl get rs web -o json | \
    jq -r '.spec.template | .+{"apiVersion": "v1", "kind": "Pod"} | .metadata |= .+ {"generateName": "web-"}'
```

このマニフェストを二回適用して、Pod を二個作ります。

```bash
kubectl get rs web -o json | \
    jq -r '.spec.template | .+{"apiVersion": "v1", "kind": "Pod"} | .metadata |= .+ {"generateName": "web-"}' | \
    kubectl create -f -
kubectl get rs web -o json | \
    jq -r '.spec.template | .+{"apiVersion": "v1", "kind": "Pod"} | .metadata |= .+ {"generateName": "web-"}' | \
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
さて、しかしこの状態は結局 Pod のオブジェクトが apiserver に登録されただけです。
この Pod を ready にするには？
そう、またもやスケジューラとkubeletさんの出番になるわけです。

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
