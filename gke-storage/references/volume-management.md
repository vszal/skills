# PVCs, Snapshots & Volume Operations

Management of storage resources via Kubernetes native objects.

## Configuration Syntax
- **StorageClass (SC):** Defines the flavor of storage.
- **PersistentVolumeClaim (PVC):** Requests a specific size and SC.
- **Binding Mode:** Use `volumeBindingMode: WaitForFirstConsumer` to align disk creation with pod scheduling (prevents zone mismatch).

## Volume Operations
- **Online Expansion:** Increase PVC size. Requires `allowVolumeExpansion: true`.
- **The Expansion Trap:** Filesystem resize only happens when the Pod is **Running**. Check for `FileSystemResizePending`.
- **Cloning:** Create a new PVC from an existing one using `dataSource`.

## Volume Snapshots
- **VolumeSnapshot:** A point-in-time handle for data.
- **Cross-Namespace Restore:** Use "Static Provisioning" with cluster-scoped `VolumeSnapshotContent`.
- [Cross-Namespace Example](../assets/examples/cross-namespace-snapshot.yaml)
