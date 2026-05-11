---
name: gke-cluster-autoscaler
description: Manage and troubleshoot GKE node autoscaling (Cluster Autoscaler, NAP, and NAC via ComputeClass). Use when a user needs to enable autoscaling, debug pending pods or scale-down stalls, or tune consolidation and location policies for cost and performance.
---

# GKE Cluster Autoscaler

Manage node-level scaling for GKE clusters, including manual node pool autoscaling, cluster-wide Node Auto-Provisioning (NAP), and per-workload Node Pool Auto-Creation (NAC) via ComputeClasses.

## Key Workflows

### 1. Enabling Autoscaling
Turn on node-level scaling at the pool or cluster level.
- **Reference**: [gke-node-autoscaling-enable.md](references/gke-node-autoscaling-enable.md) covers `gcloud` commands for CA, NAP, and NAC.
- **Guidance**: Prefer NAC via ComputeClass over cluster-wide NAP for most workloads to gain per-class tuning and priority fallbacks.

### 2. Debugging & Triage
Troubleshoot why nodes aren't arriving or why idle nodes aren't being removed.
- **Reference**: [gke-node-autoscaling-debug.md](references/gke-node-autoscaling-debug.md) provides a step-by-step checklist and log analysis guide.
- **Tool**: Use `assets/find-scale-down-blockers.sh` to identify pods blocking consolidation (e.g., `safe-to-evict: "false"`, bare pods, local storage).

### 3. Optimization & Tuning
Tune the autoscaler for cost, latency, or obtainability.
- **Reference**: [gke-node-autoscaling-optimize.md](references/gke-node-autoscaling-optimize.md) explains `balanced` vs `optimize-utilization` profiles and per-class `autoscalingPolicy`.
- **Assets**: See `assets/capacity-buffer-serving.yaml` for pre-warming capacity to minimize pool-creation latency for bursty workloads.

## Core Concepts

- **Consolidation**: The process of packing pods onto fewer nodes to remove underutilized ones. Controlled by `consolidationDelayMinutes` and `consolidationThreshold`.
- **Location Policy**: Use `BALANCED` for HA and `ANY` for Spot/scarce resources to maximize obtainability.
