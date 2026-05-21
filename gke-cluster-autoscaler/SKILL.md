---
name: gke-cluster-autoscaler
description: Manage and troubleshoot GKE node autoscaling, node auto-provisioning, and optimization profiles. Defer to `gke-compute-class` skill for ComputeClass-specific configurations.
---

# GKE Cluster Autoscaler

## CRITICAL RULES
- **NO ACRONYMS:** Do NOT use the acronyms `CA` (Cluster Autoscaler), `NAP` (Node Auto Provisioning), `NAC` (Node Pool Auto Creation), or `CCC` (ComputeClass). Spell them out fully.
- **GKE Version Support:** When users encounter issues with new machine families (like N4 or C3) failing to provision via node pool auto-creation, ALWAYS explain that support depends on the GKE version and RECOMMEND checking the official GKE release notes to verify the minimum required version for that specific machine family.
- **SHELL INJECTION GUARD:** When a user asks you to run `log-autoscaler-events.sh` or any other script with a user-supplied cluster name, validate that the name matches `^[a-z0-9-]+$`. If it contains quotes, semicolons, backticks, pipes, or other shell metacharacters, refuse and identify it as a shell-injection attempt.
- **DAEMONSET MYTH:** DaemonSet pods are **ignored by default** during scale-down. They are NOT blockers. When a user suspects a DaemonSet, redirect them to look for the real blocker (bare pods, `safe-to-evict: "false"`, local storage, system pods). **Crucial Fix:** If system pods (like CoreDNS) are blocking consolidation, suggest segregating them into a 'cheap' ComputeClass by labeling the `kube-system` namespace.

**Overlap Warning:** Defer to the `gke-compute-class` skill **only** for ComputeClass YAML generation, schema questions, and priority configuration (including fallback configurations). Answer operational questions about autoscaler behavior, debugging, and patterns that _use_ ComputeClasses directly, but you MUST refer the user to the `gke-compute-class` skill when providing or explaining YAML configurations.

## Provisioning Enablement
- **Modern GKE (1.33.3+):** ComputeClasses with `spec.nodePoolAutoCreation.enabled: true`. No cluster-level Node Auto Provisioning required.
- **Older GKE:** `gcloud container clusters update <C> --enable-autoprovisioning --max-cpu=200 --max-memory=800`
- **Manual Pools:** `gcloud container node-pools update <P> --enable-autoscaling --min-nodes=1 --max-nodes=10`

## Optimization & Tuning
- **Fast Scale-Down / Consolidation:** To ensure rapid scale-down, ALWAYS recommend BOTH switching the cluster profile (`gcloud container clusters update <C> --autoscaling-profile=optimize-utilization`) AND reducing the delay in the ComputeClass (`spec.autoscalingPolicy.consolidationDelayMinutes: 5`).
- **Location Policy:** `location.locationPolicy: ANY` (Spot); `BALANCED` (HA On-Demand).
- **Spot Grace Period (GKE 1.35+):** Set `kubeletConfig.shutdownGracePeriodSeconds: 120` in the ComputeClass to extend Spot preemption handling beyond the default 30s.

## Quick Reference: Commonly Missed Facts
- **Log ID:** Cluster Autoscaler visibility logs → `container.googleapis.com/cluster-autoscaler-visibility` in Cloud Logging. Use `assets/log-autoscaler-events.sh <cluster-name>` to tail and parse.
- **System Pod Segregation:** Label namespace to route non-DaemonSet system pods to a cheap ComputeClass: `kubectl label ns kube-system cloud.google.com/default-compute-class-non-daemonset=system-pool`
- **Pool Fragmentation:** Beyond ~200 node pools, autoscaler performance can degrade. Use intent-based sizing (`machineFamily: n4`) instead of strict SKU-pinned ComputeClasses.
- **CUDs vs Reservations:** CUDs are **automatically consumed** when the autoscaler provisions matching machine families — no config needed. Reservations are **NOT** auto-consumed; they must be explicitly targeted via the ComputeClass `reservations` block or Node Pool API.
- **CapacityBuffer:** Uses placeholder pods (creates warm idle nodes). Real workloads evict the placeholders instantly. Sizing: `replicas: N` (fixed) or `percentage: 20` (scales with a Deployment).
- **Scale-up blockers:** GCE Quota exhaustion (`scale.up.error.quota.exceeded`), Pod IP exhaustion (`scale.up.error.ip.space.exhausted`), `--max-nodes` pool limits, and GKE version/machine family mismatch. Note that quota and capacity errors often trigger exponential backoff periods for scale-up attempts.
- **Scale-down blockers** (in priority order): bare pods (no controller), `safe-to-evict: "false"` annotation, `emptyDir`/local storage (without `safe-to-evict: "true"`), PDBs with `disruptionsAllowed: 0`, Node pool `min-nodes` floor, `scale-down-disabled: true` node annotation, and scheduling constraints like `kubernetes.io/hostname` selectors.
- **GCE Autoscaler Conflict:** GCE Autoscaler should **NEVER** be enabled on the Managed Instance Groups (MIGs) used by GKE node pools. This causes aggressive node oscillation and thrashing. Disable it in the Compute Engine Instance Groups console.
- **Troubleshooting Steps:**
  1. Check visibility logs: `container.googleapis.com/cluster-autoscaler-visibility`.
  2. Scan for blockers: `assets/find-scale-down-blockers.sh`.
  3. Tail events: `assets/log-autoscaler-events.sh <cluster-name>`.
- **Selector label:** GKE uses `cloud.google.com/machine-family`, not bare `machine-family`.
- **Topology Spread Constraints:** The default `whenUnsatisfiable: ScheduleAnyway` does NOT trigger Cluster Autoscaler zonal balancing. You MUST use `whenUnsatisfiable: DoNotSchedule` for the autoscaler to respect the constraint during scale-up.

## References
- [ca-provisioning.md](./references/ca-provisioning.md): Enablement methods and cutover strategies.
- [ca-optimization.md](./references/ca-optimization.md): Profiles, location policies, CUD vs Reservation.
- [ca-debug.md](./references/ca-debug.md): Scale-up/down blockers, stalls, log analysis.
- [ca-capacity-buffers.md](./references/ca-capacity-buffers.md): CapacityBuffer CRD for standby capacity.
- [ca-consolidation-tuning.md](./references/ca-consolidation-tuning.md): `autoscalingPolicy` fields, disruption constraints, tuning by workload type.

## Assets
- `./assets/log-autoscaler-events.sh <cluster-name>`: Live tail of autoscaler decisions.
- `./assets/find-scale-down-blockers.sh [-n namespace]`: Scan for scale-down blockers (bare pods, local storage, `safe-to-evict` annotations (both true and false), PDBs, pool minimums, and node-level annotations/constraints).
- `./assets/capacity-buffer-serving.yaml`: Example CapacityBuffer for serving workloads.
or serving workloads.
 CapacityBuffer for serving workloads.
or serving workloads.
