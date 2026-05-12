---
name: gke-cluster-autoscaler
description: Manage and troubleshoot GKE node autoscaling (Cluster Autoscaler, NAP, and NAC via ComputeClass). Use for enabling autoscaling, tuning consolidation/location policies, and debugging pending pods or scale-down stalls.
---

# GKE Cluster Autoscaler

Manage node-level scaling for GKE clusters, including standard Cluster Autoscaler (CA), Node Auto-Provisioning (NAP), and Node Pool Auto-Creation (NAC).

## Quick Reference

| Task | Command / Configuration |
|------|-------------------------|
| **Enable CA (Pool)** | `gcloud container node-pools update <P> --enable-autoscaling --min-nodes=1 --max-nodes=10` |
| **Enable NAP (Cluster)** | `gcloud container clusters update <C> --enable-autoprovisioning --max-cpu=200 --max-memory=800` |
| **Enable NAC (CCC)** | `spec.nodePoolAutoCreation.enabled: true` |
| **Profile Tuning** | `gcloud container clusters update <C> --autoscaling-profile=optimize-utilization` |
| **Scale-down Delay** | `spec.autoscalingPolicy.consolidationDelayMinutes: 5` |
| **Location Policy** | `location.locationPolicy: ANY` (Preferred for Spot) |

## Reference Directory

| Topic | Reference | Description |
|-------|-----------|-------------|
| **Provisioning** | [ca-provisioning.md](./references/ca-provisioning.md) | Enabling CA, NAP, and NAC; cutover strategies; hybrid pools. |
| **Optimization** | [ca-optimization.md](./references/ca-optimization.md) | Profiles (`balanced` vs `optimize-utilization`), Location Policies, and Consolidation tuning. |
| **Debug & Perf** | [ca-debug.md](./references/ca-debug.md) | Visibility logs, scale-up/down blockers, performance bottlenecks, and system pod segregation. |
| **Pre-warming** | [ca-capacity-buffers.md](./references/ca-capacity-buffers.md) | Using the `CapacityBuffer` CRD for standby capacity and HPA headroom. |

## Assets

### [Autoscaler Log Tailer](./assets/log-autoscaler-events.sh)
Continuous live tail of all autoscaler decisions (scale-ups, NAC creations, failures, and stalls).
- **Usage:** `./assets/log-autoscaler-events.sh <cluster-name>`
- **Requires:** `roles/logging.viewer` and `gcloud`, `jq`.

### [Scale-down Blocker Scan](./assets/find-scale-down-blockers.sh)
One-shot scan for workload-side blockers (`safe-to-evict: false`, bare pods, local storage, tight PDBs).
- **Usage:** `./assets/find-scale-down-blockers.sh [-n namespace]`

### [Capacity Buffer Template](./assets/capacity-buffer-serving.yaml)
Example `CapacityBuffer` for serving workloads to ensure zero-pending-pod scaling.
