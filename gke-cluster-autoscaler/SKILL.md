---
name: gke-cluster-autoscaler
description: Manage and troubleshoot GKE node autoscaling (CA, NAP, NAC).
---

# GKE Cluster Autoscaler

Manage node-level scaling for GKE clusters.

## Cheat Sheet

| Task | Command / Configuration |
|------|-------------------------|
| **Enable CA (Pool)** | `gcloud container node-pools update <P> --enable-autoscaling --min-nodes=1 --max-nodes=10` |
| **Enable NAP (Cluster)** | `gcloud container clusters update <C> --enable-autoprovisioning --max-cpu=200 --max-memory=800` |
| **Enable NAC (CCC)** | `spec.nodePoolAutoCreation.enabled: true` |
| **Profile Tuning** | `gcloud container clusters update <C> --autoscaling-profile=optimize-utilization` |
| **Scale-down Delay** | `spec.autoscalingPolicy.consolidationDelayMinutes: 5` |
| **Location Policy** | `location.locationPolicy: ANY` (Preferred for Spot) |

## Reference Directory

| Scenario | Trigger Keywords | Reference |
|----------|-----------------|-----------|
| **Enabling** | `gcloud` enable CA, turn on NAP, total node bounds | [ca-enable-scaling.md](./references/ca-enable-scaling.md) |
| **Strategies** | manual vs NAC, hybrid strategy, cutover from NAP | [ca-provisioning-strategies.md](./references/ca-provisioning-strategies.md) |
| **Profiles** | `balanced` vs `optimize-utilization`, zone policy (`ANY`) | [ca-optimization-profiles.md](./references/ca-optimization-profiles.md) |
| **Consolidation** | `consolidationDelay`, `consolidationThreshold`, PDBs | [ca-consolidation-tuning.md](./references/ca-consolidation-tuning.md) |
| **Pre-warming** | `CapacityBuffer` CRD, standby vs active capacity | [ca-capacity-buffers.md](./references/ca-capacity-buffers.md) |
| **Debug: Scale-up** | `Pending` pods, visibility logs, `messageId` codes | [ca-debug-scale-up.md](./references/ca-debug-scale-up.md) |
| **Debug: Scale-down** | `safe-to-evict`, scale-down blockers, system pod drift | [ca-debug-scale-down.md](./references/ca-debug-scale-down.md) |
| **Debug: Speed** | sluggish scaling, pool count creep (>200), Spot grace | [ca-debug-performance.md](./references/ca-debug-performance.md) |

## Assets
- [Scale-down Blocker Scan](./assets/find-scale-down-blockers.sh)
- [Autoscaler Log Tail](./assets/log-autoscaler-events.sh)
- [Capacity Buffer Serving](./assets/capacity-buffer-serving.yaml)
