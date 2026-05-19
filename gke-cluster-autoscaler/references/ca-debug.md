# Cluster Autoscaler: Debugging & Performance

## Live Visibility Logs

- **Asset:** `assets/log-autoscaler-events.sh <cluster-name>` (Live tail).

## `messageId` Cheat Sheet
| ID | Meaning | Fix |
|----|---------|-----|
| `scale.up.error.out.of.resources` | GCE Stockout | Add zone/family fallback in ComputeClass. |
| `scale.up.error.quota.exceeded` | Project quota cap | Raise regional quota. |
| `scale.up.error.ip.space.exhausted` | Subnet full | Expand pod IP ranges. |
| `scale.up.no.scale.up` | No priority match | Check Pod requests vs ComputeClass bounds. |

## Pending Pod Checklist
1. `kubectl describe pod`: Check events for "insufficient cpu" or "taints".
2. **Hit `--max-nodes`?** Check pool limits.
3. **Selector Conflict?** Pod Pins `gke-spot=true` while ComputeClass is On-Demand.
4. **node pool auto-creation Enabled?** Check `nodePoolAutoCreation.enabled: true`.
5. **Visibility Logs:** Read `noDecisionStatus.noScaleUp` for exact rejection reason.
6. **EKS to GKE Selector Translation:** If migrating from EKS/Karpenter, ensure the user translates AWS-style or generic selectors (`machine-family`) to GKE-native ones (`cloud.google.com/machine-family`). A common cause of `scale.up.no.scale.up` is a Pod asking for `machine-family: c3` while GKE only recognizes `cloud.google.com/machine-family: c3`.

## Finding Scale-down Blockers

- **Asset:** `./assets/find-scale-down-blockers.sh` (Scan cluster for blockers).

### Common Causes
- **Bare Pods:** No controller (Deployment/Job); autoscaler won't evict.
- **Local Storage:** `emptyDir` on local SSD or `hostPath`.
- **Annotation:** `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"`.
- **PDBs:** Currently allowing zero disruptions.
- **Floor:** `min-nodes` or `total-min-nodes` > 0.

## Performance & Sluggishness
- **Required Anti-affinity:** Explodes scheduler cost at scale. Use `preferred` or `topologySpreadConstraints`.
- **Pool Count:** Beyond ~200 pools, autoscaling slows down. Consolidate near-duplicate ComputeClasses.
- **Spot Grace Period:** Default is 30s. Extend to 120s (GKE 1.35+) via `shutdownGracePeriodSeconds` in `kubeletConfig`.

## Segregating System Pods (Expert Pattern)
Symptom: `kube-system` pods (metrics-server, coredns) land on expensive nodes and pin them.
**Fix:** Segregate via namespace default ComputeClass.
1. Apply a "cheap" `system-pool` ComputeClass.
2. Label `kube-system` namespace:
   `kubectl label ns kube-system cloud.google.com/default-compute-class-non-daemonset=system-pool`
