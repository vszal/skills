---
name: gke-storage
description: Expert guide for GKE storage (PD, Hyperdisk, Filestore, GCS FUSE). Use for StorageClasses, PVCs, performance tuning, cost optimization, and high availability (Regional PD, Backup for GKE).
---

# GKE Storage Skill

Guidance on selecting, configuring, and troubleshooting storage in Google Kubernetes Engine.

## Core Architecture
GKE storage uses CSI drivers to provision Google Cloud resources via Kubernetes `StorageClasses` and `PersistentVolumeClaims` (PVCs).

### Reference Guides
- [Storage Selection & Compatibility](./references/selection.md): Choose the right type and check VM compatibility.
- [Block Storage (PD & Hyperdisk)](./references/block-storage.md): Zonal/Regional PD, Hyperdisk tiers, and Storage Pools.
- [Shared Storage (Filestore & GCS FUSE)](./references/shared-storage.md): `ReadWriteMany` options, multi-shares, and PSC networking.
- [PVCs, Snapshots & Operations](./references/volume-management.md): PVC/SC syntax, resizing, cloning, and cross-namespace restore.
- [Security & Encryption](./references/security.md): CMEK, IAM requirements, and encryption best practices.
- [Performance & Cost Optimization](./references/performance-cost.md): IOPS/Throughput scaling, `fsGroup` tuning, and cost matrix.
- [Autopilot Storage](./references/autopilot.md): Constraints and configuration for Autopilot clusters.
- [Observability, Debugging & DR](./references/observability-debug-dr.md): Metrics, logging, troubleshooting, and Backup for GKE.

## Quick Implementation
1. **Select Type:** [Selection Guide](./references/selection.md).
2. **Configure:** Define a [StorageClass](./references/volume-management.md). See [Examples](./assets/examples/).
3. **Deploy:** Reference a PVC in your Pod spec.

## Troubleshooting Workflow
1. Check PVC status: `kubectl get pvc`
2. Inspect events: `kubectl describe pvc <name>`
3. Analyze [Common Issues](./references/observability-debug-dr.md).
4. Query [CSI Logs](./assets/debug-storage-logs.sh) via Cloud Logging.
