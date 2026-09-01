# Cluster Autoscaler: Capacity Buffers & Standby Headroom

## Standby Headroom Comparison

| Mechanism | Architecture | Interaction with ComputeClass Priorities | Best For |
|---|---|---|---|
| **Manual `--min-nodes`** | Static floor on a specific manual GCE MIG | **Anti-Pattern**: `kube-scheduler` assigns incoming pods to idle nodes *before* Cluster Autoscaler evaluates ComputeClass priorities. If set on fallback pools, workloads permanently run on fallback hardware and bypass preferred tiers. | Legacy clusters without ComputeClasses. Avoid on fallback pools. |
| **`CapacityBuffer` (`buffer.x-k8s.io`)** | Dynamic or fixed balloon placeholder pods | **Recommended Golden Path**: Uses low-priority placeholder pods to hold warm nodes. Real pods preempt balloons instantly without waiting for node creation, while Cluster Autoscaler continues evaluating ComputeClass priority tiers. | Bursty serving, instant scale-up, eliminating 60–120s provisioning delay. |
| **`spec.minimumCapacity.targetNodeCount`** | Native ComputeClass CRD field (Upcoming GKE) | **Upcoming Native**: Reconciled directly by Cluster Autoscaler against the ComputeClass priority ladder. | Future native replacement for balloon pods once released in GKE. |

## `CapacityBuffer` (CRD)

- **Provisioning Strategy:** `buffer.x-k8s.io/active-capacity` (Placeholder pods).
- **Namespace-scoped:** Targets a specific `ComputeClass` via `nodeSelector` in the `podTemplateRef`.

## Sizing Modes
- **Fixed:** `replicas: 3`. Always keep N units warm.
- **Dynamic:** `percentage: 20` + `scalableRef: <Deployment>`. Headroom scales with workload.

## Why use Buffers instead of `--min-nodes`?
- **Bursty Serving:** Pod-pending SLOs can't tolerate 60-120s node pool auto-creation delay.
- **HPA outpaces cluster autoscaler:** Workload scales faster than nodes can arrive.
- **Pre-warming:** Warm GPUs/TPUs before known traffic windows.
- **Preserves ComputeClass Priorities:** Avoids the `kube-scheduler` trap where static idle nodes bypass ComputeClass evaluation.

## Architectural Flow: Scheduler vs Autoscaler

```
Incoming Pod (Targeting ComputeClass: Preferred Spot -> Fallback On-Demand)
       │
       ▼
Kubernetes kube-scheduler
       │
       ├─► Are there existing nodes with free capacity?
       │     │
       │     ├─► [YES: Idle fallback nodes held by min-nodes] ──► Pod scheduled on fallback node immediately!
       │     │                                                   (Preferred tier evaluation BYPASSED)
       │     │
       │     └─► [YES: Warm nodes held by CapacityBuffer] ────► Real pod PREEMPTS CapacityBuffer pod instantly!
       │                                                         (Runs on preferred hardware with 0s startup delay)
       │
       └─► [NO: Cluster fully utilized] ─────────────────────► Pod remains Pending
                                                                     │
                                                                     ▼
                                                  Cluster Autoscaler evaluates ComputeClass priorities:
                                                  1. Scale up Preferred Spot nodes
                                                  2. Fall back to On-Demand only on stockout
```
