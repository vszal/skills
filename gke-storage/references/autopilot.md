# Storage on GKE Autopilot

Autopilot simplifies node management but has specific storage constraints.

## Supported Storage
- **Persistent Disk:** Standard PD-CSI is supported. Use `standard-rwo` or `premium-rwo`.
- **GCS FUSE:** Supported via sidecar injection (annotate Pod with `gke-gcsfuse/volumes: "true"`).
- **Filestore:** Fully supported via Filestore CSI driver.

## Local SSD on Autopilot
Requested via `ephemeral-storage` resources and node selectors.
```yaml
resources:
  limits:
    ephemeral-storage: "375Gi"
nodeSelector:
  cloud.google.com/gke-local-nvme-ssd: "true"
```

## Constraints
- **No hostPath:** `hostPath` volumes are not allowed for security reasons. Use `emptyDir` or PVCs.
- **Automatic Sizing:** You pay for requested PVC capacity; Autopilot manages node performance limits automatically.
