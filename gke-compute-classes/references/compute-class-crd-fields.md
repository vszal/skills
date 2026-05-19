# ComputeClass: CRD Fields & Spec Reference

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
| `nodePoolAutoCreation.enabled` | Enable node pool auto-creation for this ComputeClass. **Does NOT require cluster-level Node Auto Provisioning.** | `false` |
| `nodePoolConfig` | Defaults for node pool auto-creation pools (image, SA, labels, taints). | See below. |
| `priorityDefaults` | Defaults applied to all `priorities[]` entries. | e.g. `zones`, `sysctls`. |
| `priorities[]` | Ordered list of provisioning attempts. | Tried top-to-bottom. |
| `autoscalingPolicy` | Consolidation thresholds and delay. | `1` min floor. |
| `activeMigration` | Drift logic to higher priorities. | Honors PDBs. |
| `whenUnsatisfiable` | Fallback behavior when priorities exhaust. | `DoNotScaleUp` (Default). |

## `nodePoolConfig` (node pool auto-creation Only)
Applied to pools created by the autoscaler.
- `imageType`: `cos_containerd`, `ubuntu_containerd` (must be **lowercase**).
- `nodeLabels`: Key-value pairs.
- `taints`: List of `{ key, value, effect }`. **DO NOT add `cloud.google.com/compute-class` here; GKE applies and tolerates it automatically for node pool auto-creation.**
- `serviceAccount`: Identity for nodes (use custom SA with least privilege, not default).

## `priorities[]` Fields
- `machineFamily` / `machineType`: Intent vs. strict. Prefer family.
- `minCores`, `minMemoryGb`: Lower bounds for intent-based matching.
- `spot`: `true` for Spot, `false` for On-Demand.
- `location.zones`: List of zones to attempt.
- `reservations`: `affinity: Specific` or `None`.
- `flexStart`: `{ enabled: true }` for DWS queued provisioning.
- `gpu` / `tpu`: Accelerator requests (count, type, topology).
- `nodepools`: (Standard Only) List of manual pool names to target.
- `nodeSystemConfig`: 
  - `linuxNodeConfig`: `sysctls` (e.g., `net.ipv4.tcp_tw_reuse: true`, `net.core.somaxconn: 4096`). **Never quote integer or boolean values.**
  - `kubeletConfig`: `cpuCfsQuota`, `podPidsLimit`, etc.
- `storage`: Set `bootDiskType`, `bootDiskSize`, and `localSSDCount` specifically for this priority. Overrides cluster/nodePoolConfig defaults.

## Important Schema Constraints
- **Case Sensitivity**: `imageType` must be lowercase (e.g., `cos_containerd`).
- **Field Hallucinations**: NEVER use `spec.description`, `gvnic`, `transparentHugepageEnabled`, or `shutdownGracePeriodSeconds`. They do not exist in the CRD.
- **YAML Formatting**: ALWAYS use literal integers for fields like `bootDiskSize`, `minCores`, and `somaxconn`. **DO NOT wrap them in quotes.**
  - **Correct**: `bootDiskSize: 50`
  - **Incorrect**: `bootDiskSize: "50"`
- **Storage**: Use `bootDiskSize`, NOT `bootDiskSizeGb`.

## `whenUnsatisfiable`
- `DoNotScaleUp` (Default): Pods stay `Pending`. Best for specific hardware needs.
- `ScaleUpAnyway`: Provisions **E2** nodes on Standard with node pool auto-creation. Avoid for specialized workloads.
