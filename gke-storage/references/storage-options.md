# GKE Storage Options & Selection

Select the storage type based on your workload's access pattern, performance needs, and data lifecycle.

## 1. Block Storage (Compute Engine Persistent Disk)
Best for: Single-pod access (`ReadWriteOnce`), databases, and boot disks.

| Type | GKE Name | Performance | Use Case |
| :--- | :--- | :--- | :--- |
| **Balanced** | `balanced` | Balanced IOPS/Cost | **Default choice** for most apps. |
| **Performance** | `ssd` | High IOPS | Databases (PostgreSQL, MySQL). |
| **Standard** | `pd-standard` | Throughput-optimized | Backups, logs, batch processing. |
| **Extreme** | `pd-extreme` | Ultra-high IOPS | SAP HANA, Oracle. |

### Regional Persistent Disks
- **Availability:** Replicates data across two zones in a region.
- **Failover:** Provides higher availability for stateful sets during zonal outages.

## 2. Shared File Storage (Filestore)
Best for: Multiple pods requiring simultaneous access (`ReadWriteMany`).

- **Basic SSD/HDD:** General-purpose file sharing.
- **Enterprise:** High-availability with support for **Multi-shares** (up to 80 shares per instance).
- **Zonal/Regional:** High-performance tiers for AI/ML and HPC.

### Networking: VPC Peering vs. PSC
- **VPC Peering (PSA):** Standard method. Non-transitive (cannot reach Filestore from a peered VPC without a proxy).
- **Private Service Connect (PSC):** Modern method. Transitive and uses a single IP endpoint. Simplifies multi-VPC architectures and avoids IP address conflicts.

## 3. Object Storage (Cloud Storage FUSE)
Best for: Large datasets, ML training, and cost-effective unstructured data access.

- **Mounting:** Use the GKE CSI driver to mount GCS buckets as volumes.
- **Performance:** High throughput for large files, but higher latency for metadata operations compared to PD.

### Advanced GCS FUSE Tuning
To achieve maximum performance for AI/ML workloads (e.g., A3/H100 nodes):

1. **Local SSD Caching:** Use the node's Local SSD as a cache buffer to reduce GCS latency.
   ```yaml
   # Pod Annotation
   gke-gcsfuse/volumes: "true"
   gke-gcsfuse/memory-limit: "4Gi"
   gke-gcsfuse/cpu-limit: "2"
   ```
2. **Mount Options:** Use the `serving` or `training` profiles (GKE 1.30+).
   - `mountOptions: ["profile:aiml-serving", "file-cache:enable-parallel-downloads:true"]`

| Profile | Tuning Focus | Best For |
| :--- | :--- | :--- |
| **`aiml-serving`** | Low-latency, random access | **Inference**, serving small assets. |
| **`aiml-training`** | High-throughput, sequential access | **Model Training**, large datasets. |

3. **Parallelism:** Enable `parallel-downloads-per-file: 16` for massive model weights.

## 4. Hyperdisk
Next-gen storage with independent scaling of IOPS and throughput.
- **Balanced/Extreme:** For high-performance workloads.
- **ML:** Optimized for loading massive model weights.
- **Requirement:** Requires newer VM series (e.g., C4, C3, N4, M3).

## 5. Local SSD
Best for: Caching, scratch space, and ultra-low latency requirements.
- **Persistence:** **Data is lost** when the node is deleted or the pod is moved.
- **Access:** Via the `Local SSD` CSI driver or hostPath (not recommended).

---

## Data Security & Encryption
By default, GKE storage is encrypted at rest using Google-managed keys.

### Customer-Managed Encryption Keys (CMEK)
Required for high-compliance environments (e.g., Finance, Healthcare).
- **Setup:** Specify the `disk-encryption-kms-key` parameter in your `StorageClass`.
- **IAM Requirement:** The **Compute Engine Service Agent** (`service-[PROJECT_NUMBER]@compute-system.iam.gserviceaccount.com`) must have the `Cloud KMS CryptoKey Encrypter/Decrypter` role on the key.
- **Pitfall:** Snapshots created from CMEK disks are tied to the key version. Rotating or disabling old key versions can break historical snapshot restoration.

---

## Storage on GKE Autopilot
Autopilot manages nodes automatically, but storage selection remains critical.

- **Persistent Disk:** Standard PD-CSI is supported. Use `standard-rwo` or `premium-rwo`.
- **Local SSD:** Requested via ephemeral-storage limits.
  ```yaml
  resources:
    limits:
      ephemeral-storage: "375Gi" # Requests 1 Local SSD
    requests:
      ephemeral-storage: "375Gi"
  nodeSelector:
    cloud.google.com/gke-local-nvme-ssd: "true"
  ```
- **GCS FUSE:** Fully supported via sidecar injection. Annotate the Pod with `gke-gcsfuse/volumes: "true"`.
- **Constraint:** `hostPath` is **not allowed** on Autopilot. Use `emptyDir` or PVCs.

---

## VM & Storage Compatibility Matrix

Storage options and performance are strictly tied to the node's machine series.

| Machine Series | Hyperdisk Support | Local SSD Support | Max Performance (IOPS / Throughput) |
| :--- | :--- | :--- | :--- |
| **C4, G4** | Balanced, Extreme, Throughput | Built-in (Titanium SSD) | **500k IOPS / 10 GB/s** |
| **C3, N4, Z3** | Balanced, Throughput, Extreme* | Built-in (Titanium SSD) | 350k IOPS / 5 GB/s |
| **N2, N2D, C2, C2D** | Limited | Optional (up to 9 TiB) | 100k IOPS / 1.2 GB/s |
| **M3, A3** | Extreme, ML | Optional | 350k IOPS / 5 GB/s |
| **E2, N1** | Not Supported | Optional (N1 only) | 15k IOPS / 0.4 GB/s |

**Titanium Architecture:** Powers C4, G4, and C3 series by offloading storage I/O to dedicated hardware, enabling ultra-high performance and low latency.

**Source:** [Machine type comparison](https://docs.cloud.google.com/compute/docs/machine-resource#machine_type_comparison)
