# Block Storage (Persistent Disk & Hyperdisk)

High-performance storage for single-pod workloads (ReadWriteOnce).

## Persistent Disk (PD)
- **Balanced (Default):** Optimal cost/performance for most apps.
- **Performance (SSD):** High IOPS for databases.
- **Extreme:** Ultra-high performance (SAP HANA, Oracle).
- **Regional PD:** Replicates data across two zones for RPO 0 high availability.

## Hyperdisk
Next-gen storage with performance (IOPS/Throughput) decoupled from capacity.
- **Balanced:** General high-performance apps.
- **Extreme:** Up to 500k IOPS (C4/G4).
- **ML:** Optimized for loading model weights (A3/A4 series).

### Hyperdisk Storage Pools
Aggregate performance across multiple volumes for large clusters.
- **Efficiency:** Supports **thin provisioning** and data reduction.
- **Constraint:** Supports Balanced and Throughput tiers only.

## Examples
- [Regional PD StorageClass](../assets/examples/regional-pd-sc.yaml)
- [Hyperdisk StorageClass](../assets/examples/hyperdisk-sc.yaml)
