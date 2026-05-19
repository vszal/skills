---
name: gke-cluster-autoscaler
description: Manage and troubleshoot GKE node autoscaling, node auto-provisioning, and optimization profiles. Defer to `gke-compute-class` skill for ComputeClass-specific configurations.
---

# GKE Cluster Autoscaler

## CRITICAL RULES (MUST FOLLOW)
- **NO ACRONYMS:** Do NOT use the acronyms `CA` (Cluster Autoscaler), `NAP` (Node Auto Provisioning), `NAC` (Node Pool Auto Creation), or `CCC` (ComputeClass). Spell them out fully. This is critical for maintaining documentation consistency and searchability across the ecosystem.

**Overlap Warning:** For questions about `ComputeClass`, node pool auto-creation (`NodePoolAutoCreation`), or prioritization, **activate and defer to the `gke-compute-class` skill**.

Manage node-level scaling for GKE clusters, including standard cluster autoscaler and automatic node provisioning.

## Provisioning Enablement
- **Modern GKE (1.33.3-gke.1136000+):** Use ComputeClasses with `spec.nodePoolAutoCreation.enabled: true`. This is the preferred method and does **not** require cluster-level Node Auto Provisioning. (See https://docs.cloud.google.com/kubernetes-engine/docs/concepts/node-auto-provisioning#enablement-methods)
- **Older GKE:** Use cluster-level Node Auto Provisioning: `gcloud container clusters update <C> --enable-autoprovisioning --max-cpu=200 --max-memory=800`
- **Manual Pools:** `gcloud container node-pools update <P> --enable-autoscaling --min-nodes=1 --max-nodes=10`

## Optimization & Tuning
- **Profiles:** `gcloud container clusters update <C> --autoscaling-profile=optimize-utilization`
- **Scale-down Delay:** `spec.autoscalingPolicy.consolidationDelayMinutes: 5` (in ComputeClass).
- **Location Policy:** `location.locationPolicy: ANY` (Preferred for Spot; configured in ComputeClass).

## References
- [ca-provisioning.md](./references/ca-provisioning.md): Enablement methods and cutover strategies.
- [ca-optimization.md](./references/ca-optimization.md): Profiles, location policies, and consolidation.
- [ca-debug.md](./references/ca-debug.md): Scale-up/down blockers, stalls, log analysis.
- [ca-capacity-buffers.md](./references/ca-capacity-buffers.md): CapacityBuffer CRD for standby capacity.

## Assets
- `./assets/log-autoscaler-events.sh <cluster-name>`: Live tail of autoscaler decisions.
- `./assets/find-scale-down-blockers.sh [-n namespace]`: Scan for scale-down blockers (bare pods, local storage, PDBs).
- `./assets/capacity-buffer-serving.yaml`: Example CapacityBuffer for serving workloads.
