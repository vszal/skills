# CA: Capacity Buffers (Pre-warm)

## `CapacityBuffer` (CRD)
Reserve spare capacity ahead of demand to avoid NAC/pool-creation latency.
- **Provisioning Strategy:** `buffer.x-k8s.io/active-capacity` (Placeholder pods).
- **Namespace-scoped:** Targets a specific `ComputeClass` via `nodeSelector` in the `podTemplateRef`.

## Sizing Modes
- **Fixed:** `replicas: 3`. Always keep N units warm.
- **Dynamic:** `percentage: 20` + `scalableRef: <Deployment>`. Headroom scales with workload.

## Why use Buffers?
- **Bursty Serving:** Pod-pending SLOs can't tolerate 60-120s NAC delay.
- **HPA outpaces CA:** Workload scales faster than nodes can arrive.
- **Pre-warming:** Warm GPUs/TPUs before known traffic windows.

*Note:* Replaces the "dumb" floor of `--min-nodes` with shape-aware, class-targeted warm capacity.
