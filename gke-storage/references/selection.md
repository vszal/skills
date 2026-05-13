# GKE Storage Selection & Compatibility

Select storage based on access pattern, performance needs, and VM series.

## Selection Guide

| Type | GKE Component | Access Mode | Best For |
| :--- | :--- | :--- | :--- |
| **Block** | Persistent Disk / Hyperdisk | RWO | Databases, boot disks, single pods. |
| **File** | Filestore | RWX | Shared config, legacy apps, web content. |
| **Object** | Cloud Storage FUSE | RWX | ML training datasets, unstructured data. |
| **Ephemeral** | Local SSD | RWO | Caching, scratch space, temp processing. |

## VM & Storage Compatibility Matrix

Storage performance is strictly tied to the node's machine series.

| Machine Series | Hyperdisk Support | Local SSD | Max Performance (IOPS / Throughput) |
| :--- | :--- | :--- | :--- |
| **C4, G4** | Balanced, Extreme, Throughput | Titanium SSD | **500k IOPS / 10 GB/s** |
| **C3, N4, Z3** | Balanced, Throughput, Extreme* | Titanium SSD | 350k IOPS / 5 GB/s |
| **N2, N2D, C2, C2D** | Limited | Optional | 100k IOPS / 1.2 GB/s |
| **M3, A3** | Extreme, ML | Optional | 350k IOPS / 5 GB/s |
| **E2, N1** | Not Supported | N1 only | 15k IOPS / 0.4 GB/s |

**Titanium Architecture:** Enables C4, G4, and C3 series to offload storage I/O to dedicated hardware for ultra-low latency.

**Source:** [Machine type comparison](https://docs.cloud.google.com/compute/docs/machine-resource#machine_type_comparison)
