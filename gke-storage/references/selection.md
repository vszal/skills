# GKE Storage Selection & Compatibility

Select storage based on access pattern, performance needs, and VM series.

## Selection Guide

| Type | GKE Component | Access Mode | Best For |
| :--- | :--- | :--- | :--- |
| **Block** | Persistent Disk / Hyperdisk | RWO | Databases, boot disks, single pods. |
| **File** | Filestore | RWX | Shared config, legacy apps, web content. |
| **Object** | Cloud Storage FUSE | RWX | ML training datasets, unstructured data. |
| **Ephemeral** | Local SSD | RWO | Caching, scratch space, temp processing. |

**Local SSD caveat:** Highest IOPS, but **ephemeral and node-local** — data is lost when the pod moves or the node is repaired/recreated/upgraded. Use only for regenerable scratch/cache. Prefer it over `emptyDir` on the boot disk, which throttles the whole node under heavy I/O.

## VM & Storage Compatibility Matrix

Storage performance is strictly tied to the node's machine series.

| Machine Series | Hyperdisk Support | Local SSD | Max Performance (IOPS / Throughput) |
| :--- | :--- | :--- | :--- |
| **C4, G4** | Balanced, Extreme, Throughput | Titanium SSD | **500k IOPS / 10 GB/s** |
| **C3, N4, Z3** | Balanced, Throughput, Extreme* | Titanium SSD | 350k IOPS / 5 GB/s |
| **N2, N2D, C2, C2D** | Limited | Optional | 100k IOPS / 1.2 GB/s |
| **M3, A3** | Extreme, ML | Optional | 350k IOPS / 5 GB/s |
| **E2, N1** | Not Supported | N1 only | 15k IOPS / 0.4 GB/s |

**Hyperdisk-only series:** The newest series (e.g. **N4, C4, G4**) support **only Hyperdisk — they cannot attach Persistent Disk**. A `pd-balanced`/`pd-ssd` StorageClass will fail to provision/attach there (`FailedAttachVolume`, pods `Pending`); switch the StorageClass to a Hyperdisk type (or use a series that still supports PD).

**Mixed-series / autoscaled clusters — use `dynamic-rwo` (GKE 1.35.3-gke.1290000+):** When a cluster spans both PD-capable and Hyperdisk-only series — common with the Cluster Autoscaler or **ComputeClasses** falling back across machine series (xref gke-compute-classes) — a single fixed `pd-*`/`hyperdisk-*` StorageClass is fragile: the autoscaler can scale up an incompatible node → `FailedAttachVolume`/`Pending`. The built-in **`dynamic-rwo`** StorageClass (`type: dynamic` + `use-allowed-disk-topology: "true"`) fixes both halves: `type: dynamic` provisions **PD or Hyperdisk per node**; `use-allowed-disk-topology` makes the **Cluster Autoscaler disk-topology-aware**, scaling up **only disk-compatible nodes**. Reference by name on supported clusters; see [block-storage.md](./block-storage.md), [dynamic-rwo-sc.yaml](../assets/examples/dynamic-rwo-sc.yaml). (`dynamic` = *balanced* tiers — for a specific Hyperdisk tier use a dedicated Hyperdisk StorageClass.)

**Titanium Architecture:** Enables C4, G4, and C3 series to offload storage I/O to dedicated hardware for ultra-low latency.

**Source:** [Machine type comparison](https://docs.cloud.google.com/compute/docs/machine-resource#machine_type_comparison)
