# PVCs and StorageClasses in GKE

Dynamic provisioning simplifies storage management by decoupling storage requests from infrastructure details.

## StorageClasses (SC)
A `StorageClass` defines the "flavor" of storage (e.g., SSD, Regional, Filestore).

### Default StorageClass
In GKE, the default SC is usually `standard-rwo` (Balanced PD). You can check it with:
```bash
kubectl get storageclass
```

### Key Parameters
- `type`: `pd-balanced`, `pd-ssd`, `pd-standard`.
- `replication-type`: `none` (zonal) or `regional-pd`.
- `allowVolumeExpansion`: Always set to `true` to allow resizing.
- `volumeBindingMode`: `WaitForFirstConsumer` is recommended for zonal PDs to ensure the disk is created in the same zone as the pod.

## PersistentVolumeClaims (PVC)
A PVC is a request for storage by a user.

### Example: Regional SSD PVC
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: regional-ssd-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: regional-ssd
```

## Volume Operations

### Resizing Volumes & Troubleshooting
1. Edit the PVC: `kubectl edit pvc <pvc-name>`
2. Increase the `spec.resources.requests.storage` value.
3. **The Expansion Process:**
   - **Step 1: Block Growth:** The CSI driver expands the GCE disk.
   - **Step 2: Filesystem Resize:** The kernel resizes the filesystem (ext4/xfs). **This only happens when the volume is mounted by a Running Pod.**

**Common Issue: `FileSystemResizePending`**
If the PVC status stays in this state for a long time:
- Ensure the Pod is `Running`. If it's stuck in `Pending` or `ContainerCreating`, the resize cannot occur.
- Restart the Pod to force a remount if the automatic resize is delayed.
- Verify the filesystem is **ext4** or **xfs**; other types may not support online expansion.

### Snapshots and Cloning
GKE supports standard Kubernetes VolumeSnapshots.
- **Cloning:** You can create a new PVC from an existing PVC using `dataSource`.
- **Snapshots:** Use `VolumeSnapshotClass` and `VolumeSnapshot` objects.
- **Cross-Namespace Restore:** Use "Static Provisioning" to bridge snapshots between namespaces. See the [Cross-Namespace Example](../assets/examples/cross-namespace-snapshot.yaml).

## ReadWriteMany (RWX) Patterns
Persistent Disks only support `ReadWriteOnce`. For RWX:
1. Use **Filestore** with the `filestore.csi.storage.gke.io` driver.
2. Use **Cloud Storage FUSE** for object-based shared access.
