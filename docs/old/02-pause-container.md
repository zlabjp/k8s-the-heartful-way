# ノードに pod が割り当てられたので pause コンテナー作成します

## pause コンテナ起動

```bash
# TODO: labels
docker run -d \
    --network none \
    --name k8s_POD_default-nginx \
    k8s.gcr.io/pause:3.1
```

## コンテナネットワークへ参加

```bash
sudo su

pid=$(docker inspect -f '{{ .State.Pid }}' k8s_POD_default-nginx)
netns=/proc/$pid/ns/net
export CNI_PATH=/opt/cni/bin
export CNI_COMMAND=ADD
export PATH=$CNI_PATH:$PATH
export CNI_CONTAINERID=k8s_POD_default-nginx
export CNI_NETNS=$netns
export POD_SUBNET=$(kubectl get node alice -o jsonpath="{.spec.podCIDR}")

export CNI_IFNAME=eth0
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

export CNI_IFNAME=lo
/opt/cni/bin/loopback <<EOF
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF
```

## nginx 起動

```bash
docker run -d \
    --network container:k8s_POD_default-nginx \
    --name k8s_nginx_nginx_default \
    nginx:1.14
```

```
docker run -d \
    --network container:k8s_POD_default-nginx \
    --name test \
    busybox \
    sleep 10000
```

## スケジューリングされた後の status の動き

### Container 作成中

```diff
 {
   "apiVersion": "v1",
   "kind": "Pod",
   "metadata": {
     "creationTimestamp": "2019-01-22T08:15:09Z",
     "labels": {
       "run": "nginx"
     },
     "name": "nginx",
     "namespace": "default",
-    "resourceVersion": "1073420",
+    "resourceVersion": "1073422",
     "selfLink": "/api/v1/namespaces/default/pods/nginx",
     "uid": "d56afd24-1e1d-11e9-8dbd-fa163e0919ba"
   },
   "spec": {
     "containers": [
       {
         "image": "nginx",
         "imagePullPolicy": "Always",
         "name": "nginx",
         "resources": {
         },
         "terminationMessagePath": "/dev/termination-log",
         "terminationMessagePolicy": "File",
         "volumeMounts": [
           {
             "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount",
             "name": "default-token-7blw4",
             "readOnly": true
           }
         ]
       }
     ],
     "dnsPolicy": "ClusterFirst",
     "enableServiceLinks": true,
     "nodeName": "yuanying-worker-10d3ba27-jt259-demo-swkdn-caas",
     "priority": 0,
     "restartPolicy": "Never",
     "schedulerName": "default-scheduler",
     "securityContext": {
     },
     "serviceAccount": "default",
     "serviceAccountName": "default",
     "terminationGracePeriodSeconds": 30,
     "tolerations": [
       {
         "effect": "NoExecute",
         "key": "node.kubernetes.io/not-ready",
         "operator": "Exists",
         "tolerationSeconds": 300
       },
       {
         "effect": "NoExecute",
         "key": "node.kubernetes.io/unreachable",
         "operator": "Exists",
         "tolerationSeconds": 300
       }
     ],
     "volumes": [
       {
         "name": "default-token-7blw4",
         "secret": {
           "defaultMode": 420,
           "secretName": "default-token-7blw4"
         }
       }
     ]
   },
   "status": {
     "conditions": [
+      {
+        "lastProbeTime": null,
+        "lastTransitionTime": "2019-01-22T08:15:09Z",
+        "status": "True",
+        "type": "Initialized"
+      }
+      {
+        "lastProbeTime": null,
+        "lastTransitionTime": "2019-01-22T08:15:09Z",
+        "message": "containers with unready status: [nginx]",
+        "reason": "ContainersNotReady",
+        "status": "False",
+        "type": "Ready"
+      }
+      {
+        "lastProbeTime": null,
+        "lastTransitionTime": "2019-01-22T08:15:09Z",
+        "message": "containers with unready status: [nginx]",
+        "reason": "ContainersNotReady",
+        "status": "False",
+        "type": "ContainersReady"
+      }
     ],
     "phase": "Pending",
     "qosClass": "BestEffort"
+    "containerStatuses": [
+      {
+        "image": "nginx",
+        "imageID": "",
+        "lastState": {
+        },
+        "name": "nginx",
+        "ready": false,
+        "restartCount": 0,
+        "state": {
+          "waiting": {
+            "reason": "ContainerCreating"
+          }
+        }
+      }
+    ]
+    "hostIP": "10.30.100.166"
+    "startTime": "2019-01-22T08:15:09Z"
   }
 }
```


### Container 出来上がった

```diff
 {
   "apiVersion": "v1",
   "kind": "Pod",
   "metadata": {
     "creationTimestamp": "2019-01-22T08:15:09Z",
     "labels": {
       "run": "nginx"
     },
     "name": "nginx",
     "namespace": "default",
-    "resourceVersion": "1073422",
+    "resourceVersion": "1073432",
     "selfLink": "/api/v1/namespaces/default/pods/nginx",
     "uid": "d56afd24-1e1d-11e9-8dbd-fa163e0919ba"
   },
   "spec": {
     "containers": [
       {
         "image": "nginx",
         "imagePullPolicy": "Always",
         "name": "nginx",
         "resources": {
         },
         "terminationMessagePath": "/dev/termination-log",
         "terminationMessagePolicy": "File",
         "volumeMounts": [
           {
             "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount",
             "name": "default-token-7blw4",
             "readOnly": true
           }
         ]
       }
     ],
     "dnsPolicy": "ClusterFirst",
     "enableServiceLinks": true,
     "nodeName": "yuanying-worker-10d3ba27-jt259-demo-swkdn-caas",
     "priority": 0,
     "restartPolicy": "Never",
     "schedulerName": "default-scheduler",
     "securityContext": {
     },
     "serviceAccount": "default",
     "serviceAccountName": "default",
     "terminationGracePeriodSeconds": 30,
     "tolerations": [
       {
         "effect": "NoExecute",
         "key": "node.kubernetes.io/not-ready",
         "operator": "Exists",
         "tolerationSeconds": 300
       },
       {
         "effect": "NoExecute",
         "key": "node.kubernetes.io/unreachable",
         "operator": "Exists",
         "tolerationSeconds": 300
       }
     ],
     "volumes": [
       {
         "name": "default-token-7blw4",
         "secret": {
           "defaultMode": 420,
           "secretName": "default-token-7blw4"
         }
       }
     ]
   },
   "status": {
     "conditions": [
       {
         "lastProbeTime": null,
         "lastTransitionTime": "2019-01-22T08:15:09Z",
         "status": "True",
         "type": "Initialized"
       },
       {
         "lastProbeTime": null,
-        "lastTransitionTime": "2019-01-22T08:15:09Z",
+        "lastTransitionTime": "2019-01-22T08:15:13Z",
-        "message": "containers with unready status: [nginx]",
-        "reason": "ContainersNotReady",
-        "status": "False",
+        "status": "True",
         "type": "Ready"
       },
       {
         "lastProbeTime": null,
-        "lastTransitionTime": "2019-01-22T08:15:09Z",
+        "lastTransitionTime": "2019-01-22T08:15:13Z",
-        "message": "containers with unready status: [nginx]",
-        "reason": "ContainersNotReady",
-        "status": "False",
+        "status": "True",
         "type": "ContainersReady"
       },
       {
         "lastProbeTime": null,
         "lastTransitionTime": "2019-01-22T08:15:09Z",
         "status": "True",
         "type": "PodScheduled"
       }
     ],
     "containerStatuses": [
       {
-        "image": "nginx",
+        "image": "nginx:latest",
-        "imageID": "",
+        "imageID": "docker-pullable://nginx@sha256:b543f6d0983fbc25b9874e22f4fe257a567111da96fd1d8f1b44315f1236398c",
         "lastState": {
         },
         "name": "nginx",
-        "ready": false,
+        "ready": true,
         "restartCount": 0,
         "state": {
-          "waiting": {
-            "reason": "ContainerCreating"
-          }
+          "running": {
+            "startedAt": "2019-01-22T08:15:13Z"
+          }
         }
+        "containerID": "docker://c6c73a90ed2d5af7100d2e55496a3d7ddeb329ab4fdbe00329647770866ea558"
       }
     ],
     "hostIP": "10.30.100.166",
-    "phase": "Pending",
+    "phase": "Running",
     "qosClass": "BestEffort",
     "startTime": "2019-01-22T08:15:09Z"
+    "podIP": "10.26.62.46"
   }
 }
```