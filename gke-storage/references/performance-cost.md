# Performance & Cost Optimization

Balance storage speed and monthly spend.

## Performance Scaling
- **Linear Scaling:** PD IOPS and throughput scale with disk size (GiB) until instance limits are reached.
- **Instance Limits:** Small VMs (e.g., e2-medium) have much lower limits than high-end series.
- **Throughput Sharing:** Storage throughput shares the VM's egress bandwidth.
- **Boot Disk Throttling Trap:** High I/O activity inside `/var/lib/kubelet` (like `emptyDir` mounts or container overlays) consumes the node's boot disk IOPS. Because GKE boot disks are typically small (100GB), heavy temporary file writes can throttle the entire node's performance. Use local SSDs or dedicated PDs for high-I/O temporary scratch space.

## Cost Optimization Matrix

| Need | Cost-Effective | Premium |
| :--- | :--- | :--- |
| **Standard App** | Balanced PD | Performance PD |
| **Small Shared RWX** | Filestore Multi-share | Filestore Single-share |
| **High Availability** | Zonal PD + Snapshots | Regional PD (2x cost) |
| **Large Dataset** | Cloud Storage FUSE | Massive PD |

## Diagnosing Slow I/O
When a workload is slow but CPU/memory are fine, check **disk** performance in Cloud Monitoring (use [disk-perf-metrics.sh](../assets/disk-perf-metrics.sh)):
- **Metrics:** IOPS (`read/write_ops_count`), throughput (`read/write_bytes_count`), I/O latency, queue length, and **throttled operations**.
- **Bound type:** Small random I/O is **IOPS-bound**; large sequential I/O is **throughput-bound**.
- **Throttling signal:** High throttled-ops, or peak IOPS sitting at the provisioned/size-derived ceiling, means disk-bound.
- **Fixes:** Grow the disk (PD scales with size), raise `provisioned-iops/throughput-on-create` (Hyperdisk), or move to a larger / Titanium-capable machine series. Remember throughput shares the VM's egress bandwidth.

## Best Practices
- **Right-sizing:** Monitor `kubernetes.io/pv/disk/used_bytes` to identify over-provisioning.
- **Storage Pools:** Aggregate IOPS and use thin provisioning to save 20-40% on large-scale PD deployments.
