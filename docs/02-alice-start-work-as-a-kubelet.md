## アリスが出勤

```
cat > alice-ready-patch.json <<EOF
{
  "status": {
    "conditions": [
      {
        "lastHeartbeatTime": "$(date --utc +"%Y-%m-%dT%H:%M:%SZ")",
        "message": "Starting work as a kubelet",
        "reason": "KubeletReady",
        "status": "True",
        "type": "Ready"
      }
    ]
  }
}
EOF

curl -X PATCH -H "Content-Type: application/strategic-merge-patch+json" --data-binary @alice-ready-patch.json "http://127.0.0.1:8001/api/v1/nodes/alice/status"
```
