# Prerequisites

```
$ vagrant up
```

```
$ vagrant ssh master01 -c "cat /vagrant/kubernetes/admin.yaml" > /tmp/admin.yaml
$ export KUBECONFIG=/tmp/admin.yaml
$ kubectl apply -f ../deploy/
node/alice created
node/bob created
secret/default-token created
serviceaccount/default created
pod/nginx created
$ kubectl get nodes
NAME    STATUS    ROLES    AGE   VERSION
alice   Unknown   <none>   18s
bob     Unknown   <none>   18s
```
