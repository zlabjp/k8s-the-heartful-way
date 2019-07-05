## アリスが出勤

```
cat > alice-ready-patch.json <<EOF
{
  "status": {
    "conditions": [
      {
        "lastHeartbeatTime": "$(date --utc +"%Y-%m-%dT%H:%M:%SZ")",
        "message": "Starting work as a kubelet",
        "reason": "KubeletNotReady",
        "status": "False",
        "type": "Ready"
      }
    ]
  }
}
EOF

curl -k -X PATCH -H "Content-Type: application/strategic-merge-patch+json" \
  --key /vagrant/kubernetes/secrets/admin.key \
  --cert /vagrant/kubernetes/secrets/admin.crt \
  --data-binary @alice-ready-patch.json "https://127.0.0.1:6443/api/v1/nodes/yuanying/status"
```
