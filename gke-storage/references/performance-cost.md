# Performance & Cost Trade-offs

Optimizing GKE storage involves balancing throughput, IOPS, and budget.

## Performance Scaling Factors

### 1. Disk Size
For most Persistent Disk types, IOPS and throughput scale linearly with the disk size until they hit the limit for the machine type.
- **Rule of Thumb:** A 1 TiB Balanced PD has significantly higher performance than a 100 GiB one.

### 2. Machine Type (VM Compatibility)
Storage performance is capped by the VM's vCPU count and machine generation.
- **vCPU Count:** Reaching maximum PD limits often requires nodes with **64+ vCPUs**.
- **Generation:** Newer series like **C4/G4** leverage **Titanium offload** to reach up to 500k IOPS.

### 3. Hyperdisk: Performance Decoupled from Capacity
Hyperdisk allows you to provision performance independently of size.

| Type | Max IOPS | Max Throughput | Best For |
| :--- | :--- | :--- | :--- |
| **Balanced** | 160,000 | 2,400 MB/s | General high-performance apps. |
| **Extreme** | **500,000** | **10,000 MB/s** | Latency-critical databases (C4/G4). |
| **ML** | N/A | 1,200 MB/s per TiB | **AI/ML Model Weights** (A3/A4 series). |

### 4. Network Limits
GCE Persistent Disks are network-attached. Total storage throughput shares the VM's egress bandwidth.

## Hyperdisk Storage Pools
For large-scale deployments, Storage Pools offer a way to aggregate and share performance.
- **Consolidation:** Aggregate IOPS/Throughput across multiple volumes.
- **Efficiency:** Supports **thin provisioning** (pay only for used GiB) and data reduction (deduplication/compression).
- **Constraint:** Currently supports **Balanced** and **Throughput** tiers only (Extreme is not supported in pools).

## Mount Performance Optimization
A common issue with large filesystems (especially Filestore or multi-TB PDs) is slow pod startup times.

### The `fsGroup` Trap
By default, Kubernetes recursively calls `chown` and `chmod` on every file in a volume if an `fsGroup` is specified in the Pod's `securityContext`. For 10TB+ volumes with many small files, this can take **30+ minutes** and cause high CPU usage.

**Solution:** Use `fsGroupChangePolicy: "OnRootMismatch"`.
```yaml
securityContext:
  fsGroup: 2000
  fsGroupChangePolicy: "OnRootMismatch"
```
This tells Kubernetes to only perform the recursive walk if the root directory's permissions don't already match the `fsGroup`.

## Cost Optimization Matrix

| Requirement | Cost-Effective Solution | Premium Solution |
| :--- | :--- | :--- |
| **Single Pod Storage** | Balanced PD | Performance PD / Hyperdisk |
| **Shared Storage (RWX)** | Filestore Enterprise (Multi-shares) | Filestore High-Performance |
| **Massive Data** | Cloud Storage FUSE | Large PD / Filestore |
| **High Availability** | Zonal PD with Snapshots | Regional PD (2x cost) |
| **Short-lived Cache** | emptyDir (RAM/Local) | Local SSD |

## Best Practices for Cost
- **Right-sizing:** Use Cloud Monitoring to identify over-provisioned volumes.
- **Snapshot Retention:** Implement lifecycle policies to delete old snapshots.
- **Filestore Multi-shares:** Consolidate many small shares (e.g., 10GiB each) into a single Enterprise Filestore instance to save costs.
- **Autopilot:** Autopilot automatically manages underlying node types, but you still pay for the requested PVC capacity.
