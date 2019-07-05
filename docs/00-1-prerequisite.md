# 環境

`vagrant provision` or `vagrant up` でとりあえず以下の環境は用意されているはず。

-   Node の登録
-   inajob/yuanying ノードの起動
-   yuanying ノードのセットアップ

## Kubernetes

-   admin 用 kubeconfig の場所
    -   `/vagrant/kubernetes/admin.yaml`
-   admin 用、各証明書、鍵の場所
    -   `/vagrant/kubernetes/secrets/admin.key`
    -   `/vagrant/kubernetes/secrets/amidn.crt`
-   各ノードには KUBECONFIG が `~vagrant/.kube/config` が配られているので、そのまま `kubectl` が叩ける状態になっている。

## 注意事項
- node はたくさん登録されているが、実際にあるノードは yuanying と inajob だけ。
