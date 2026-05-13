# Observability & Debugging GKE Storage

Effective monitoring and a systematic troubleshooting approach are key to maintaining healthy stateful workloads.

## Monitoring with Cloud Monitoring
GKE automatically exports storage metrics to Google Cloud Monitoring.

### Key Metrics to Watch
- **Volume IOPS:** `kubernetes.io/pv/disk/read_ops_count` / `write_ops_count`
- **Throughput:** `kubernetes.io/pv/disk/read_bytes_count` / `write_bytes_count`
- **Latency:** `kubernetes.io/pv/disk/operation_latencies`
- **Capacity:** `kubernetes.io/pv/disk/used_bytes` vs `total_bytes`

## Troubleshooting Common Issues

### 1. `FailedAttachVolume` / `FailedMount`
**Symptoms:** Pod stuck in `ContainerCreating` or `Pending`.
- **Causes:**
  - Disk is already attached to another node (Multi-attach error).
  - Zone mismatch between Pod and Zonal PD.
  - Max disk attach limit reached for the VM type.
- **Fix:** Check `kubectl describe pod <name>` for events. Use `WaitForFirstConsumer` in StorageClass.

### 2. Volume Expansion Failures
**Symptoms:** PVC size updated in K8s but not reflected in the disk or filesystem.
- **Causes:**
  - `allowVolumeExpansion` is `false` in StorageClass.
  - Filesystem error or disk busy.
- **Fix:** Check PVC events. Verify the underlying GCE disk size in the Cloud Console.

### 3. Performance Bottlenecks
**Symptoms:** High disk latency, application timeouts.
- **Causes:**
  - Disk size too small (throttling).
  - VM vCPU count too low for desired throughput.
  - Node network congestion.
- **Fix:** Increase PVC size. Upgrade node machine type.

## Disaster Recovery & Migration

### Migrating from Zonal to Regional PD
If you need to move a stateful workload from Zonal to Regional PD for higher availability:
1. **Snapshot the Zonal PD:** Create a volume snapshot of the existing disk.
2. **Create a Regional PD from Snapshot:** Provision a new `PersistentVolume` using the snapshot as the source and specifying `replication-type: regional-pd`.
3. **Update StatefulSet:** Point the StatefulSet's volumeClaimTemplates to the new Regional StorageClass.

### Backup & Business Continuity
While `VolumeSnapshots` provide data-layer copies, **Backup for GKE** is a managed service that captures the entire workload.

| Feature | VolumeSnapshots (CSI) | Backup for GKE |
| :--- | :--- | :--- |
| **Scope** | Data only (PVs) | **Data + Config** (YAMLs, Secrets) |
| **Consistency** | Crash-consistent | **App-consistent** (via Hooks) |
| **Management** | Manual/Scripts | Fully Managed Service |

**Enable with:** `gcloud container clusters update [NAME] --enable-gke-backup`

### CSI Driver Lifecycle
- **Addon Check:** Ensure the `GcePersistentDiskCsiDriver` addon is ENABLED, especially for clusters upgraded from v1.18 or older.
- **Legacy Removal:** In-tree drivers were removed in v1.25. All persistent storage must use CSI drivers.

### Handling Zonal Outages
- **Zonal PD:** If a zone fails, the disk is inaccessible. You must wait for the zone to recover or restore from a recent snapshot into a different zone.
- **Regional PD:** GKE automatically handles failover. The pod will be rescheduled in the healthy zone and the disk will be re-attached with 0 data loss (RPO 0).

## Deep Dive with Cloud Logging
For issues that aren't resolved by `kubectl describe`, use Cloud Logging to inspect the CSI driver internal operations.

### Common Log Queries
- **PD CSI Errors:** Search for `AttachVolume` or `NodePublishVolume` in the `gce-pd-driver` container.
- **Filestore Errors:** Search for `CreateInstance` in the `filestore-driver` container.
- `K8s Events:` Filter for `FailedMount` or `FailedAttachVolume` in the `k8s_cluster` resource.

See the [Debugging Queries Script](../assets/debug-storage-logs.sh) for a complete list of ready-to-use logging filters.

## Logs for Deep Dive
If Kubernetes events are insufficient, check the CSI driver logs in the `kube-system` namespace:
- **PD CSI:** `gce-pd-csi-node` and `gce-pd-csi-controller`.
- **Filestore CSI:** `filestore-csi-node` and `filestore-csi-controller`.
