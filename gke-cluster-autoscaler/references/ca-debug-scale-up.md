# CA: Debugging Scale-up

## Visibility Logs (Primary Tool)
Filter: `log_id("container.googleapis.com/cluster-autoscaler-visibility")`
- **Asset:** `assets/log-autoscaler-events.sh <cluster>` (Live tail).

## `messageId` Cheat Sheet
| ID | Meaning | Fix |
|----|---------|-----|
| `scale.up.error.out.of.resources` | GCE Stockout | Add zone/family fallback in CCC. |
| `scale.up.error.quota.exceeded` | Project quota cap | Raise regional quota. |
| `scale.up.error.ip.space.exhausted` | Subnet full | Expand pod IP ranges. |
| `scale.up.no.scale.up` | No priority match | Check Pod requests vs CCC bounds. |

## Pending Pod Checklist
1. `kubectl describe pod`: Check events for "insufficient cpu" or "taints".
2. **Hit `--max-nodes`?** Check pool limits.
3. **Selector Conflict?** Pod Pins `gke-spot=true` while CCC is On-Demand.
4. **NAC Enabled?** Check `nodePoolAutoCreation.enabled: true`.
5. **Visibility Logs:** Read `noDecisionStatus.noScaleUp` for exact rejection reason.

*Note:* If decisions are being made but are extremely slow, see [ca-debug-performance.md](./ca-debug-performance.md).
