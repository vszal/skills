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

## Examples
- [Filestore Multi-share SC](../assets/examples/filestore-sc.yaml)
- [GCS FUSE PVC](../assets/examples/gcs-fuse-pvc.yaml)
