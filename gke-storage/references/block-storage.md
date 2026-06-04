# Block Storage (Persistent Disk & Hyperdisk)

High-performance storage for single-pod workloads (ReadWriteOnce).

**Provisioner (`provisioner:` field):** both PD and Hyperdisk use the exact string `pd.csi.storage.gke.io` — write it in full, never a bare `csi.storage.gke.io`.

## Persistent Disk (PD)
- **Balanced (Default):** Optimal cost/performance for most apps.
- **Performance (SSD):** High IOPS for databases.
- **Extreme:** Ultra-high performance (SAP HANA, Oracle).
- **Regional PD (HA):** Synchronous replication across two zones for RPO 0 / automatic zonal failover — the standard choice for HA stateful workloads (e.g. databases). In `parameters` set `replication-type: regional-pd` **plus** `type: pd-balanced` (or `pd-ssd`), and list **two zones** under top-level `allowedTopologies`. The exact parameter is `replication-type` — never `regional: "true"` or `replicationType`. See [regional-pd-sc.yaml](../assets/examples/regional-pd-sc.yaml).
- **Literal `type:` values:** `pd-balanced` (default), `pd-ssd`, `pd-extreme`, `pd-standard` — PD types **keep** the `pd-` prefix. Never write a bare `ssd`/`balanced`.

## Hyperdisk
Next-gen storage with performance (IOPS/Throughput) decoupled from capacity.
- **Balanced:** General high-performance apps.
- **Extreme:** Up to 500k IOPS (C4/G4).
- **ML:** Optimized for loading model weights (A3/A4 series).
- **Tier selection & compatibility:** IOPS and throughput are tunable **independently of capacity** (unlike PD, which scales performance with disk size). Match the tier to the workload — Extreme (or Balanced for moderate needs) for latency-sensitive/transactional databases; **ML** for high-read-throughput model-weight loading. Tier availability and the max IOPS/throughput a volume can hit are **bounded by the node machine series** — verify the node pool supports the tier (see the [machine-type support table](selection.md)).
- **Literal `type:` values:** `hyperdisk-balanced`, `hyperdisk-extreme`, `hyperdisk-throughput`, `hyperdisk-ml` — Hyperdisk **drops** the `pd-` prefix (this exception applies to Hyperdisk only; PD types above keep it).
- **Provisioned Performance:** Pin guaranteed IOPS/throughput at creation via StorageClass parameters `provisioned-iops-on-create` (e.g. `"5000"`) and `provisioned-throughput-on-create` in **MiB/s** (e.g. `"250Mi"`) — both string values, bounded by the disk type and node machine-series limits. See [hyperdisk-provisioned-sc.yaml](../assets/examples/hyperdisk-provisioned-sc.yaml).

### Hyperdisk Storage Pools
Aggregate performance across multiple volumes for large clusters.
- **Efficiency:** Supports **thin provisioning** and data reduction.
- **Constraint:** Supports Balanced and Throughput tiers only.
- **Usage:** In the StorageClass `parameters`, set `type: hyperdisk-balanced` (or `hyperdisk-throughput`) **plus** `storage-pools:` = the pool's resource path. There is no `tier` or `thinProvisioning` parameter — thin provisioning is inherent to the pool. `volumeBindingMode: WaitForFirstConsumer` is **required** — the pool and its volumes must be in the **same zone**, and WFC keeps the disk there. Put `volumeBindingMode`, `allowVolumeExpansion`, and `reclaimPolicy` at the **top level** of the StorageClass, *not* under `parameters:`. See [storage-pool-sc.yaml](../assets/examples/storage-pool-sc.yaml).

## CMEK StorageClass
Set `disk-encryption-kms-key` to the full KMS key path. Encryption applies to **new disks only** and is **permanent**. Grant the Compute Engine Service Agent `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the key (see [security.md](./security.md)). Example: [cmek-sc.yaml](../assets/examples/cmek-sc.yaml).

## Examples
- [Regional PD StorageClass](../assets/examples/regional-pd-sc.yaml)
- [Hyperdisk StorageClass](../assets/examples/hyperdisk-sc.yaml)
