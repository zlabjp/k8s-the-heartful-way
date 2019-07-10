# 環境

`vagrant provision` or `vagrant up` でとりあえず以下の環境は用意されているはず。

-   Node の登録
    -   master01: 192.168.43.101
    -   inajob: 192.168.43.111
    -   yuanying: 192.168.43.112
-   inajob/yuanying ノードの起動
-   yuanying ノードのセットアップ

## Kubernetes

-   admin 用 kubeconfig の場所
    -   `/vagrant/kubernetes/secrets/admin.yaml`
-   admin 用、各証明書、鍵の場所
    -   `/vagrant/kubernetes/secrets/admin.key`
    -   `/vagrant/kubernetes/secrets/amidn.crt`
-   各ノードには KUBECONFIG が `~vagrant/.kube/config` が配られているので、そのまま `kubectl` が叩ける状態になっている。

## 注意事項
-   node はたくさん登録されているが、実際にあるノードは yuanying と inajob だけ。
-   `iptables -P FORWARD ACCEPT` しないとノードをまたがった Pod 間通信ができない。ノードを再起動すると消えるので要注意。

