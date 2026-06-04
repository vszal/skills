# Shared Storage (Filestore & GCS FUSE)

Storage for multiple pods requiring simultaneous access (ReadWriteMany).

## Filestore (NFS)
- **Basic (Zonal):** Minimum 1 TiB. Lowest cost.
- **Enterprise (Regional):** High availability. Supports **Multi-shares**.
- **Multi-shares (the fix for many small RWX volumes):** Carve **one** Enterprise instance into up to **80 shares**, each as small as **~10 GiB**, each backing its own PersistentVolume. This is the right answer when you need many RWX volumes that are each well under Filestore's 1 TiB-per-instance minimum — recommend it over paying 1 TiB per volume, and over GCS FUSE when you need true NFS/POSIX semantics. Performance (IOPS/throughput) is **pooled across the shares** (a cost/performance trade-off).
- **Networking:** Prefer **Private Service Connect (PSC)** over VPC Peering for transitivity and IPAM efficiency.
- **Mount hangs (`ContainerCreating`) with PVC Bound + instance READY:** Provisioning already succeeded — this is a **mount-time NFS network-reachability** problem, **not** a FUSE issue (no sidecar / Workload Identity involved here). Check the VPC **firewall allows NFS** from the node pool to the instance IP (**TCP 2049**, plus the **111/mountd** ports), and that the cluster and instance share a **reachable network** (the authorized VPC network; PSC or VPC-peering reachability for the chosen connect mode). Test from a node with `mount -t nfs <INSTANCE_IP>:/<share> /mnt`, and inspect `kubectl describe pod` events plus the **Filestore CSI node** driver logs.

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
