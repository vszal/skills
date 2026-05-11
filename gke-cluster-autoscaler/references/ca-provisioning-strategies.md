# CA: Provisioning Strategies & Cutover

## Comparison: Manual vs. NAC vs. Hybrid
| Strategy | Strengths | Use Case |
|----------|-----------|----------|
| **Manual Pools** | Fast scheduling; Stable names (`nodepools: []` refs). | Latency-sensitive; manual management. |
| **NAC (CCC)** | Best obtainability; Scale-to-zero (empty pools deleted). | Bursty; batch; cost-sensitive. |
| **Hybrid** | Manual pool at top for fast-path; NAC fallback for scale. | **Most Production Workloads.** |

## Cutover: NAP to NAC
1. **Apply CCCs:** Create classes with `nodePoolAutoCreation.enabled: true`.
2. **Opt Workloads In:** Apply `nodeSelector: cloud.google.com/compute-class: <name>`.
3. **Drain Old Pools:** `kubectl drain` nodes in old NAP-managed pools to force move to new CCC nodes.
4. **Disable NAP:** (Optional) If cluster-wide caps aren't needed, disable with `--no-enable-autoprovisioning`.

## Scale-to-Zero Note
- **Manual Pools:** Standard CA keeps ≥1 node (last node not deleted).
- **NAC-managed:** Autoscaler can delete the entire pool when empty.
- **Autopilot:** Managed by GKE; pod-billed pricing ($0 when idle).
