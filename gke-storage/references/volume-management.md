# PVCs, Snapshots & Volume Operations

Management of storage resources via Kubernetes native objects.

## Configuration Syntax
- **StorageClass (SC):** Defines the flavor of storage.
  - **provisioner (required, exact string):** PD & Hyperdisk → `pd.csi.storage.gke.io`; Filestore → `filestore.csi.storage.gke.io`; GCS FUSE → `gcsfuse.csi.storage.gke.io`. Never abbreviate to a bare `csi.storage.gke.io`. `parameters`, `volumeBindingMode`, `allowVolumeExpansion`, and `reclaimPolicy` are **top-level** SC fields — not nested under `parameters:`.
  - **Do NOT Edit Defaults:** The GKE Addon Manager (`EnsureExists`) will revert manual modifications to default StorageClasses (e.g., `standard-rwo`). Always create a *new* custom StorageClass instead — set your desired `type`, `volumeBindingMode`, and (for regional/multi-zone) `allowedTopologies` on it. To make it the cluster default, move the `storageclass.kubernetes.io/is-default-class: "true"` annotation onto the new class and off `standard-rwo`.
  - **Topology Constraints:** For regional or multi-zone setups, explicitly define `allowedTopologies`. Omitting this forces GKE to provision the underlying disk strictly where compute is currently available, potentially locking pods out of future zonal expansion.
- **PersistentVolumeClaim (PVC):** Requests a specific size and SC.
- **Binding Mode:** Use `volumeBindingMode: WaitForFirstConsumer` to align disk creation with pod scheduling. *Note: This causes the PVC to stay in the `Pending` state until a Pod references it and is scheduled. This is expected behavior, not an error.* GKE's **built-in `standard-rwo` and `premium-rwo` classes already use `WaitForFirstConsumer`** — so a PVC on either one sitting `Pending` with **no events** is normal and clears the moment a Pod mounts it; deploy that Pod rather than debugging a non-existent provisioning failure.

## Volume Operations
- **Online Expansion:** Grow PVC size — requires `allowVolumeExpansion: true` on the SC. A PVC can only be **grown, never shrunk**.
- **The Expansion Trap (`FileSystemResizePending`):** Disk/block expansion completes first; the **filesystem** resize only happens when the Pod is **Running** and remounts the volume — so the PV/disk can show the new size while the Pod still sees the old one. Clear a stuck `FileSystemResizePending` by restarting/recreating the consuming Pod (this triggers the node-side filesystem resize). Pre-req: the SC must have had `allowVolumeExpansion: true`.
- **Cloning:** Create a new PVC from an existing one using `dataSource`.

## Deletion & Finalizers
- **reclaimPolicy:** With `Delete` (common default), deleting a released PVC destroys the backing disk and its data permanently. Use `Retain` to preserve the disk.
- **Deleting an in-use PVC (safe order):** `kubectl delete pvc` on a PVC a running Pod still references does **not** delete immediately — the `pvc-protection` (and `pv-protection`) finalizers hold it in `Terminating` until the consuming Pod is gone. Safe order: (1) scale down / delete the consuming Pod, (2) snapshot or back up the data, (3) prefer `reclaimPolicy: Retain` so the disk survives, then (4) delete. Never force-remove the finalizer to "unstick" it — that is what protects against data loss.
- **PV/PVC stuck in `Terminating` (diagnosis):** This almost always means a **Pod still references the PVC** — the `pvc-protection`/`pv-protection` finalizer is doing its job, not malfunctioning. Find the consuming Pod (`kubectl get pods --all-namespaces`) and delete/scale it down; the finalizer then clears on its own. **Do NOT** `kubectl patch … -p '{"metadata":{"finalizers":null}}'` to force it, and **do NOT** flip `reclaimPolicy` from `Retain` to `Delete` to "clean it up" — both bypass the safety mechanism and risk permanent data loss.

## Volume Snapshots
- **VolumeSnapshot:** A point-in-time handle for data.
- **Cross-Namespace Restore:** Use "Static Provisioning" with cluster-scoped `VolumeSnapshotContent`.
- **Migration (zone/type/region):** A PV's type and zone cannot change in place. To move data (e.g. zonal PD → regional PD, or across regions), snapshot the source PVC, then create a new PVC with `dataSource` referencing the `VolumeSnapshot` on the target StorageClass. Quiesce writes (or take an app-consistent backup) before snapshotting.
- [Cross-Namespace Example](../assets/examples/cross-namespace-snapshot.yaml)
