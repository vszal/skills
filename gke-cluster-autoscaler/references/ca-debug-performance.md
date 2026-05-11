# CA: Performance & Sluggishness

## Scaling Latency (Workload Causes)
- **Required Anti-affinity:** Explodes scheduler cost at scale. Use `preferred` or `topologySpreadConstraints`.
- **Strict Spread:** `whenUnsatisfiable: DoNotSchedule` is expensive. Use `ScheduleAnyway`.
- **Taints without Selectors:** Scheduler must evaluate and reject every node. Always pair taints with `nodeSelector`.
- **Pool Count:** Beyond ~200 pools, autoscaling slows down. Consolidate near-duplicate CCCs.

## Spot Preemption Handling
- **Grace Period:** Default is 30s.
- **Extend to 120s (GKE 1.35+):** Set `shutdownGracePeriodSeconds: 120` in `kubeletConfig` system configuration.
- **Node Termination Handler:** NOT needed on GKE; kubelet handles metadata signal directly.

## Cluster Caps
- **Supported Limit:** 5,000 nodes.
- **Hard Cap:** 15,000 nodes (requires quota).
- **Throughput:** ~100 pods/sec beyond 500 nodes.
