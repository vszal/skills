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
- **Literal `type:` values:** `hyperdisk-balanced`, `hyperdisk-extreme`, `hyperdisk-throughput`, `hyperdisk-ml` (no `pd-` prefix).
- **Provisioned Performance:** Pin guaranteed IOPS/throughput at creation via StorageClass parameters `provisioned-iops-on-create` (e.g. `"5000"`) and `provisioned-throughput-on-create` in **MiB/s** (e.g. `"250Mi"`) — both string values, bounded by the disk type and node machine-series limits. See [hyperdisk-provisioned-sc.yaml](../assets/examples/hyperdisk-provisioned-sc.yaml).

### Hyperdisk Storage Pools
Aggregate performance across multiple volumes for large clusters.
- **Efficiency:** Supports **thin provisioning** and data reduction.
- **Constraint:** Supports Balanced and Throughput tiers only.
- **Usage:** In the StorageClass `parameters`, set `type: hyperdisk-balanced` (or `hyperdisk-throughput`) **plus** `storage-pools:` = the pool's resource path. There is no `tier` or `thinProvisioning` parameter — thin provisioning is inherent to the pool. Pool and volumes must be in the **same zone** (use `WaitForFirstConsumer`). See [storage-pool-sc.yaml](../assets/examples/storage-pool-sc.yaml).

## CMEK StorageClass
Set `disk-encryption-kms-key` to the full KMS key path. Encryption applies to **new disks only** and is **permanent**. Grant the Compute Engine Service Agent `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the key (see [security.md](./security.md)). Example: [cmek-sc.yaml](../assets/examples/cmek-sc.yaml).

## Examples
- [Regional PD StorageClass](../assets/examples/regional-pd-sc.yaml)
- [Hyperdisk StorageClass](../assets/examples/hyperdisk-sc.yaml)
