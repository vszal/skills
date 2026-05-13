# Observability, Debugging & DR

Monitoring health, fixing issues, and ensuring business continuity.

## Monitoring
- **Metrics:** Track IOPS, throughput, latency, and capacity via Cloud Monitoring.
- **Logging:** Use [CSI Debugging Queries](../assets/debug-storage-logs.sh) in Logs Explorer.

## Troubleshooting Common Issues
- **FailedAttachVolume (Attach/Detach Thrashing):** Often caused by rapid StatefulSet rollouts or zonal mismatch. Disks can get stuck swapping between nodes waiting on the GCE controller. Check Pod events.
- **Multi-Zone PV Affinity Conflicts:** A RWO Persistent Disk is tied to a single zone. If a PV is created in Zone A, but the Pod is rescheduled to Zone B due to compute constraints, the Pod will hang in `Pending` due to strict PV Node Affinity.
- **VolumeCapabilities is Invalid:** Occurs when requesting `spec.accessModes: ReadWriteMany` on a standard GCE Persistent Disk (which only supports RWO). You must use Filestore or Hyperdisk Multi-zone for multi-writer access.
- **FailedMount:** Check firewall rules (Filestore) or sidecar status (GCS FUSE).
- **Expansion Pending:** Ensure Pod is `Running`; filesystem resize won't happen if Pod is stuck.
- **ZONE_RESOURCE_POOL_EXHAUSTED:** A GCE capacity stockout. Occurs during dynamic volume creation if the region lacks capacity for large or specific Hyperdisks.

## Backup & Disaster Recovery (DR)
- **Backup for GKE:** Managed service for **Data + Config** (YAMLs, Secrets). Supports app-consistent hooks.
- **Regional PD:** Synchronous replication (RPO 0) for automatic zonal failover.
- **Migration:** Use Volume Snapshots to migrate from Zonal to Regional PD or between regions.

## CSI Driver Lifecycle
- **Addon Status:** Ensure `GcePersistentDiskCsiDriver` is ENABLED. Missing default StorageClasses are often caused by this driver being disabled.
- **Legacy Driver:** In-tree drivers (pre-v1.25) are removed; all storage must use CSI.
