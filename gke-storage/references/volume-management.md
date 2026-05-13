# PVCs, Snapshots & Volume Operations

Management of storage resources via Kubernetes native objects.

## Configuration Syntax
- **StorageClass (SC):** Defines the flavor of storage.
  - **Do NOT Edit Defaults:** The GKE Addon Manager (`EnsureExists`) will revert manual modifications to default StorageClasses (e.g., `standard-rwo`). Always create a *new* custom StorageClass.
  - **Topology Constraints:** For regional or multi-zone setups, explicitly define `allowedTopologies`. Omitting this forces GKE to provision the underlying disk strictly where compute is currently available, potentially locking pods out of future zonal expansion.
- **PersistentVolumeClaim (PVC):** Requests a specific size and SC.
- **Binding Mode:** Use `volumeBindingMode: WaitForFirstConsumer` to align disk creation with pod scheduling. *Note: This causes the PVC to stay in the `Pending` state until a Pod references it and is scheduled. This is expected behavior, not an error.*

## Volume Operations
- **Online Expansion:** Increase PVC size. Requires `allowVolumeExpansion: true`.
- **The Expansion Trap:** Filesystem resize only happens when the Pod is **Running**. Check for `FileSystemResizePending`.
- **Cloning:** Create a new PVC from an existing one using `dataSource`.

## Deletion & Finalizers
- **Stuck in Terminating:** If you delete a PVC/PV before the referencing Pod is cleanly evicted, it will hang indefinitely in the `Terminating` state. This is due to the `kubernetes.io/pv-protection` finalizer locking the resource to prevent data loss.

## Volume Snapshots
- **VolumeSnapshot:** A point-in-time handle for data.
- **Cross-Namespace Restore:** Use "Static Provisioning" with cluster-scoped `VolumeSnapshotContent`.
- [Cross-Namespace Example](../assets/examples/cross-namespace-snapshot.yaml)
