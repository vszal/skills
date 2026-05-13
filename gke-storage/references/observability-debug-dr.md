# Observability, Debugging & DR

Monitoring health, fixing issues, and ensuring business continuity.

## Monitoring
- **Metrics:** Track IOPS, throughput, latency, and capacity via Cloud Monitoring.
- **Logging:** Use [CSI Debugging Queries](../assets/debug-storage-logs.sh) in Logs Explorer.

## Troubleshooting Common Issues
- **FailedAttachVolume:** Usually zonal mismatch or multi-attach (disk stuck on old node). Check Pod events.
- **FailedMount:** Check firewall rules (Filestore) or sidecar status (GCS FUSE).
- **Expansion Pending:** Ensure Pod is `Running`; filesystem resize won't happen if Pod is stuck.

## Backup & Disaster Recovery (DR)
- **Backup for GKE:** Managed service for **Data + Config** (YAMLs, Secrets). Supports app-consistent hooks.
- **Regional PD:** Synchronous replication (RPO 0) for automatic zonal failover.
- **Migration:** Use Volume Snapshots to migrate from Zonal to Regional PD or between regions.

## CSI Driver Lifecycle
- **Addon Status:** Ensure `GcePersistentDiskCsiDriver` is ENABLED.
- **Legacy Driver:** In-tree drivers (pre-v1.25) are removed; all storage must use CSI.
