# Shared Storage (Filestore & GCS FUSE)

Storage for multiple pods requiring simultaneous access (ReadWriteMany).

## Filestore (NFS)
- **Basic (Zonal):** Minimum 1 TiB. Lowest cost.
- **Enterprise (Regional):** High availability. Supports **Multi-shares**.
- **Multi-shares:** Consolidate up to 80 small shares (min 10GiB) into one Enterprise instance.
- **Networking:** Prefer **Private Service Connect (PSC)** over VPC Peering for transitivity and IPAM efficiency.

## Cloud Storage FUSE (Object)
Mount GCS buckets as volumes. Best for massive data throughput.
- **Mount Profiles:** Use `aiml-serving` for inference and `aiml-training` for dataset access.
- **Caching:** Use node Local SSD as a cache buffer via Pod annotations.

### Performance Tuning
- **Parallelism:** Enable `parallel-downloads-per-file: 16` for large model weights.
- **Resources:** Increase sidecar CPU/Memory limits for high-throughput training.

### FUSE Troubleshooting
- **Auth (`PermissionDenied`/`Unauthenticated`):** FUSE authenticates via **Workload Identity** — bind the Kubernetes SA to a principal with bucket access (e.g. `roles/storage.objectViewer`). A node pool created **before** Workload Identity was enabled lacks the GKE Metadata Server and fails until enabled; credential propagation takes a few minutes. Never loosen bucket ACLs or embed SA keys.
- **Sidecar OOMKilled / slow:** The auto-injected FUSE sidecar is under-resourced. Raise (or unset → unlimited) via Pod annotations `gke-gcsfuse/memory-limit`, `gke-gcsfuse/cpu-limit`, `gke-gcsfuse/ephemeral-storage-limit` ("0" = unlimited) — tune the sidecar, not the app container.
- **Many small files / metadata storms:** Enable the **metadata (stat/type) cache and file cache** and raise capacity/TTL to cut repeated `GetObjectMetadata` calls; back the file cache with Local SSD. Use `implicit-dirs` for directory semantics.
- **Not POSIX:** Eventual consistency and weak concurrent-write semantics — suits read-heavy serving/training, not transactional writes. Tuned example: [fuse-tuned-pod.yaml](../assets/examples/fuse-tuned-pod.yaml).

## Examples
- [Filestore Multi-share SC](../assets/examples/filestore-sc.yaml)
- [GCS FUSE PVC](../assets/examples/gcs-fuse-pvc.yaml)
- [Tuned FUSE Pod (cache + sidecar resources)](../assets/examples/fuse-tuned-pod.yaml)
