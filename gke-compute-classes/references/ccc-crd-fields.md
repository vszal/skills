# CCC: CRD Fields & Spec Reference

Full CRD: `kubectl describe crd computeclasses.cloud.google.com`.

## Minimal Shape
```yaml
apiVersion: cloud.google.com/v1
kind: ComputeClass
metadata: { name: my-class }
spec:
  nodePoolAutoCreation: { enabled: true }
  priorities:
  - machineFamily: n4
    minCores: 16
```

## Top-Level Spec Fields
| Field | Purpose | Default / Note |
|-------|---------|----------------|
| `nodePoolAutoCreation.enabled` | Enable dynamic pool creation (NAC). | `false` |
| `nodePoolConfig` | Defaults for NAC pools (image, SA, labels, taints). | See below. |
| `priorityDefaults` | Defaults applied to all `priorities[]` entries. | e.g. `zones`, `sysctls`. |
| `priorities[]` | Ordered list of provisioning attempts. | Tried top-to-bottom. |
| `autoscalingPolicy` | Consolidation thresholds and delay. | `1` min floor. |
| `activeMigration` | Drift logic to higher priorities. | Honors PDBs. |
| `whenUnsatisfiable` | Fallback behavior when priorities exhaust. | `DoNotScaleUp` (Default). |

## `nodePoolConfig` (NAC Only)
Applied to pools created by the autoscaler.
- `imageType`: `COS_CONTAINERD`, `UBUNTU_CONTAINERD`.
- `nodeLabels`: Key-value pairs.
- `taints`: List of `{ key, value, effect }`.
- `serviceAccount`: Identity for nodes.

## `priorities[]` Fields
- `machineFamily` / `machineType`: Intent vs. strict. Prefer family.
- `minCores`, `minMemoryGb`: Lower bounds for intent-based matching.
- `spot`: `true` for Spot, `false` for On-Demand.
- `location.zones`: List of zones to attempt.
- `reservations`: `affinity: Specific` or `None`.
- `flexStart`: `{ enabled: true }` for DWS queued provisioning.
- `gpu` / `tpu`: Accelerator requests (count, type, topology).
- `nodepools`: (Standard Only) List of manual pool names to target.
- `nodeSystemConfig`: `linuxNodeConfig` (sysctls, hugepages) and `kubeletConfig`.
- `storage`: Set `bootDiskType`, `bootDiskSizeGb`, and `localSsdCount` specifically for this priority. Overrides cluster/nodePoolConfig defaults.

## `whenUnsatisfiable`
- `DoNotScaleUp` (Default): Pods stay `Pending`. Best for specific hardware needs.
- `ScaleUpAnyway`: Provisions **E2** nodes on Standard with NAC. Avoid for specialized workloads.
