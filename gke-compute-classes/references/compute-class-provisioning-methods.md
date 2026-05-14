# ComputeClass: Provisioning Methods & Binding

## node pool auto-creation vs. Manual Node Pools
| Method | Description | Pinning via `nodepools` |
|--------|-------------|-------------------------|
| **node pool auto-creation** (Dynamic) | Autoscaler creates/deletes pools on demand. | ❌ (Ephemeral names) |
| **Manual** | Pre-provisioned by admin. Faster scheduling. | ✅ (Stable names) |

### Custom Node Initialization
ComputeClass Node Auto-Provisioning (node pool auto-creation) dynamically manages nodes and **does not natively support custom UserData or startup scripts** via the `nodePoolConfig`. To initialize nodes:
1. **Privileged DaemonSets (Recommended):** Deploy a DaemonSet with an `initContainer` to perform host-level setup or install proprietary monitoring agents.
2. **Custom OS Images:** GKE supports custom OS images via the [gke-custom-image-builder](https://github.com/GoogleCloudPlatform/gke-custom-image-builder-cos) (Private preview; contact account team), though DaemonSets are the primary K8s-native workaround.

### Hybrid Strategy
Put manual pools at the top for zero-latency scheduling; use node pool auto-creation fallbacks below for infinite scale.

## Intent-based vs. Strict Configuration
- **Intent-based (Preferred):** `machineFamily: n4`, `minCores: 16`. Allows GKE to find best-fit shape or substitute families.
- **Strict:** `machineType: n4-standard-16`. Pins to exact SKU.

## Binding Manual Pools to ComputeClass
Manual pools must be labeled/tainted to be eligible for a ComputeClass (unless it's the cluster default).
```bash
gcloud container node-pools update <POOL> \
    --node-labels="cloud.google.com/compute-class=<CLASS-NAME>" \
    --node-taints="cloud.google.com/compute-class=<CLASS-NAME>:NoSchedule"
```
ComputeClass auto-tolerates these taints; workloads do **not** need matching tolerations.

## Default Class Selection
- **Cluster Default:** Create ComputeClass named `default` + enable feature on cluster.
- **Namespace Default:** Label NS `cloud.google.com/default-compute-class=<name>`.
- **Workload Selection:** `nodeSelector: cloud.google.com/compute-class: <name>`.
