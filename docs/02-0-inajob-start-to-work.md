# 稲津くんの出勤 @inajob node で作業

## この章で学ぶこと

-   ワーカーノードは自身の状態を apiserver に登録する

## 解説

-   ワーカーノードが apiserver に自身の情報を登録することで、Kubernetes はそのノードをスケジュール対象として利用開始します。

## 出勤

さて、次の日です、今日から本格的に kubelet として働き始めます。

出勤したらまずはともあれ出勤システムに出勤を記録することになっています。X社ではもちろんそのシステムは Kubernetes です。
Nodeオブジェクトの status を更新して、Ready にしてやることで通勤になる仕組みです。

現状は、Status Unknown になっています。

```bash
kubectl get node | grep --color -E "^|inajob.+$"
```

昨日と同じように status を更新するには curl を利用する必要があります。Readyのステータスは以下のようになります。

```
STATUS=$(cat <<EOF
{
  "status": {
    "conditions": [
      {
        "lastHeartbeatTime": "$(date --utc +"%Y-%m-%dT%H:%M:%SZ")",
        "message": "今日からよろしくお願いします。",
        "reason": "稲津出社",
        "status": "True",
        "type": "Ready"
      }
    ]
  }
}
EOF
)
```

これを apiserver に登録することで、稲津くんが出勤したことがわかります。

```
curl -k -X PATCH -H "Content-Type: application/strategic-merge-patch+json" \
    --key ~vagrant/secrets/user.key \
    --cert ~vagrant/secrets/user.crt \
    --data-binary "${STATUS}" "https://192.168.43.101:6443/api/v1/nodes/inajob/status"
```

STATUS が Ready になりました。

```
kubectl get node | grep --color -E "^|inajob.+$"
```
