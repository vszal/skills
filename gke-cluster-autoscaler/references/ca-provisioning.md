# CA: Provisioning & Strategies

## Enabling Scaling (Standard)

### Cluster Autoscaler (CA) - Per Pool
Adds/removes nodes within `[min, max]` for an existing pool.
- **Enable (New Pool):**
  ```bash
  gcloud container node-pools create <POOL> \
    --enable-autoscaling --min-nodes=1 --max-nodes=10
  ```
- **Enable (Existing Pool):**
  ```bash
  gcloud container clusters update <CLUSTER> \
    --enable-autoscaling --node-pool=<POOL> \
    --min-nodes=1 --max-nodes=10
  ```

### Node Auto-Provisioning (NAP) - Cluster-wide
Creates **new node pools** within cluster-wide resource caps.
- **Enable:**
  ```bash
  gcloud container clusters update <CLUSTER> \
    --enable-autoprovisioning \
    --min-cpu=4 --max-cpu=200 \
    --min-memory=16 --max-memory=800
  ```

### Node Pool Auto-Creation (NAC) - Per ComputeClass
Preferred for per-workload shape control. Scoped to a CCC.
- **Enable:** Set `nodePoolAutoCreation.enabled: true` in the ComputeClass.
- **GKE 1.33.3+:** Works without cluster-wide NAP enabled.

## Provisioning Strategies

| Strategy | Strengths | Use Case |
|----------|-----------|----------|
| **Manual Pools** | Fast scheduling; Stable names. | Latency-sensitive; manual management. |
| **NAC (CCC)** | Best obtainability; Scale-to-zero. | Bursty; batch; cost-sensitive. |
| **Hybrid** | Manual pool at top; NAC fallback. | **Recommended for Production.** |

## Cutover: NAP to NAC
1. **Apply CCCs:** Create classes with `nodePoolAutoCreation.enabled: true`.
2. **Opt Workloads In:** Apply `nodeSelector: cloud.google.com/compute-class: <name>`.
3. **Drain Old Pools:** `kubectl drain` nodes in old NAP-managed pools.

## Scale-to-Zero Behavior
- **Manual Pools:** Standard CA keeps ≥1 node unless empty pool deletion is supported/enabled.
- **NAC-managed:** Autoscaler can delete the entire pool when empty.
