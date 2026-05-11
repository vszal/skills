# CCC: Provisioning Methods & Binding

## NAC vs. Manual Node Pools
| Method | Description | Pinning via `nodepools` |
|--------|-------------|-------------------------|
| **NAC** (Dynamic) | Autoscaler creates/deletes pools on demand. | ❌ (Ephemeral names) |
| **Manual** | Pre-provisioned by admin. Faster scheduling. | ✅ (Stable names) |

### Hybrid Strategy
Put manual pools at the top for zero-latency scheduling; use NAC fallbacks below for infinite scale.

## Intent-based vs. Strict Configuration
- **Intent-based (Preferred):** `machineFamily: n4`, `minCores: 16`. Allows GKE to find best-fit shape or substitute families.
- **Strict:** `machineType: n4-standard-16`. Pins to exact SKU.

## Binding Manual Pools to CCC
Manual pools must be labeled/tainted to be eligible for a CCC (unless it's the cluster default).
```bash
gcloud container node-pools update <POOL> \
    --node-labels="cloud.google.com/compute-class=<CLASS-NAME>" \
    --node-taints="cloud.google.com/compute-class=<CLASS-NAME>:NoSchedule"
```
CCC auto-tolerates these taints; workloads do **not** need matching tolerations.

## Default Class Selection
- **Cluster Default:** Create CCC named `default` + enable feature on cluster.
- **Namespace Default:** Label NS `cloud.google.com/default-compute-class=<name>`.
- **Workload Selection:** `nodeSelector: cloud.google.com/compute-class: <name>`.
