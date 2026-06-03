# PVCs, Snapshots & Volume Operations

Management of storage resources via Kubernetes native objects.

## Configuration Syntax
- **StorageClass (SC):** Defines the flavor of storage.
  - **Do NOT Edit Defaults:** The GKE Addon Manager (`EnsureExists`) will revert manual modifications to default StorageClasses (e.g., `standard-rwo`). Always create a *new* custom StorageClass instead — set your desired `type`, `volumeBindingMode`, and (for regional/multi-zone) `allowedTopologies` on it. To make it the cluster default, move the `storageclass.kubernetes.io/is-default-class: "true"` annotation onto the new class and off `standard-rwo`.
  - **Topology Constraints:** For regional or multi-zone setups, explicitly define `allowedTopologies`. Omitting this forces GKE to provision the underlying disk strictly where compute is currently available, potentially locking pods out of future zonal expansion.
- **PersistentVolumeClaim (PVC):** Requests a specific size and SC.
- **Binding Mode:** Use `volumeBindingMode: WaitForFirstConsumer` to align disk creation with pod scheduling. *Note: This causes the PVC to stay in the `Pending` state until a Pod references it and is scheduled. This is expected behavior, not an error.*

## Volume Operations
- **Online Expansion:** Increase PVC size. Requires `allowVolumeExpansion: true`.
- **The Expansion Trap:** Filesystem resize only happens when the Pod is **Running**. Clear `FileSystemResizePending` by restarting/recreating the consuming Pod so the node remounts and resizes the filesystem.
- **No Shrink:** A PVC can only be grown, never shrunk.
- **Cloning:** Create a new PVC from an existing one using `dataSource`.

## Deletion & Finalizers
- **reclaimPolicy:** With `Delete` (common default), deleting a released PVC destroys the backing disk and its data permanently. Use `Retain` to preserve the disk.
- **Deleting an in-use PVC (safe order):** `kubectl delete pvc` on a PVC a running Pod still references does **not** delete immediately — the `pvc-protection` (and `pv-protection`) finalizers hold it in `Terminating` until the consuming Pod is gone. Safe order: (1) scale down / delete the consuming Pod, (2) snapshot or back up the data, (3) prefer `reclaimPolicy: Retain` so the disk survives, then (4) delete. Never force-remove the finalizer to "unstick" it — that is what protects against data loss.

## Volume Snapshots
- **VolumeSnapshot:** A point-in-time handle for data.
- **Cross-Namespace Restore:** Use "Static Provisioning" with cluster-scoped `VolumeSnapshotContent`.
- **Migration (zone/type/region):** A PV's type and zone cannot change in place. To move data (e.g. zonal PD → regional PD, or across regions), snapshot the source PVC, then create a new PVC with `dataSource` referencing the `VolumeSnapshot` on the target StorageClass. Quiesce writes (or take an app-consistent backup) before snapshotting.
- [Cross-Namespace Example](../assets/examples/cross-namespace-snapshot.yaml)
