# ComputeClass: Lifecycle, Drift & Updates

## Consolidation (Scale-down)
Controlled via `spec.autoscalingPolicy`.
- `consolidationDelayMinutes`: Floor is **1 minute**.
- `consolidationThreshold`: CPU utilization % (0 = always candidate).
- `gpuConsolidationThreshold`: Accelerator utilization %.
- *Note:* Maintenance windows do **not** block consolidation. Use PDBs to suppress disruption.
- *Blockers:* Local storage, 'safe-to-evict: false', and bare pods block scale-down. **DaemonSets do NOT block scale-down by default.** If empty nodes aren't scaling down, look for other blocking system pods.

## ActiveMigration (Drift)
Reconciles pods back to higher-priority rules (similar to Karpenter drift).
- `optimizeRulePriority: true`: Enables the drift controller.
- **Disruption:** Honors PDBs. Without a PDB, eviction is uncontrolled.
- **Trigger:** Higher-priority capacity becomes available.

## Updating a ComputeClass
- **No Retroactive Change:** Updating a ComputeClass does **not** change existing nodes.
- **New Nodes Only:** Only nodes created after the update use the new spec.
- **Drift Behavior:**
    - *Without ActiveMigration:* Old-spec nodes persist until rescheduled (rollout, drain, preemption).
    - *With ActiveMigration:* Controller drifts pods toward nodes matching the updated (higher-priority) spec.
- **Disruption-Sensitive:** For training/stateful roles, schedule updates for maintenance windows or drain manually.
