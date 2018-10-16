## [WIP] Pod をノードに割り当てる

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

Nodes を取得する。

```bash
$ curl -s http://127.0.0.1:8001/api/v1/nodes | jq -r '.items[] | .metadata.name'
minikube
```

`minikube` node に `nginx` Pod をアサインする。

```bash
$ NAMESPACE="default" POD_NAME="nginx" NODE_NAME="minikube"
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
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {

  },
  "status": "Success",
  "code": 201
}%
```
