---
name: gke-storage
description: Comprehensive guide for GKE storage topics, including StorageClasses, PVCs, performance vs cost trade-offs, and best practices. Use this skill when the user asks about persistent storage, shared file systems, mounting buckets, or optimizing storage performance and costs on GKE.
---

# GKE Storage Skill

Expert guidance on selecting, configuring, and troubleshooting storage in Google Kubernetes Engine.

## Core Concepts

GKE storage is managed primarily through the Container Storage Interface (CSI) drivers, which allow for dynamic provisioning of Google Cloud storage resources using Kubernetes native objects like `StorageClasses` and `PersistentVolumeClaims` (PVCs).

### Quick Navigation
- [Storage Options & Selection](./references/storage-options.md): Choose between Block (PD/Hyperdisk), File (Filestore), and Object (GCS FUSE) storage.
- [Performance & Cost Trade-offs](./references/performance-cost.md): Optimize for IOPS, throughput, and budget.
- [PVCs and StorageClasses](./references/pvcs-storageclasses.md): Configuration, dynamic provisioning, and volume management.
- [Observability & Debugging](./references/observability-debugging.md): Monitoring health and troubleshooting common issues.

## Implementation Guide

### 1. Select the Right Storage Type
- **Standard Apps:** Use **Balanced Persistent Disk** (default).
- **High-Performance DBs:** Use **Performance PD** or **Hyperdisk Extreme**.
- **Shared Storage (RWX):** Use **Filestore** or **Cloud Storage FUSE**.
- **Ephemeral/Cache:** Use **Local SSD**.

### 2. Configure StorageClasses
Define your requirements in a `StorageClass` to automate provisioning. 
See [Example Configurations](./assets/examples/).

### 3. Use PersistentVolumeClaims
Pods request storage by referencing a PVC.
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: premium-rwo
```

## Best Practices
- **High Availability:** Use **Regional Persistent Disks** for critical stateful workloads to protect against zonal failures.
- **Cost Efficiency:** Use **Filestore Multi-shares** for multiple small `ReadWriteMany` volumes.
- **Scaling:** Remember that PD performance scales with disk size and node vCPU count.
- **Backup:** Implement **Volume Snapshots** via the GKE CSI driver.

## Debugging Workflow
1. Check PVC status: `kubectl get pvc`
2. Describe PVC for events: `kubectl describe pvc <name>`
3. Check CSI driver logs in the `kube-system` namespace.
4. Verify VM attach limits and machine type compatibility.
Detailed guide: [Observability & Debugging](./references/observability-debugging.md)
