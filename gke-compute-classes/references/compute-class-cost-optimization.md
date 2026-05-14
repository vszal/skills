# ComputeClass: Cost Optimization & FlexCUDs

## Aligning with Flexible Committed Use Discounts (FlexCUDs)
FlexCUDs provide predictable, high-value discounts in exchange for a commitment to spend a specific amount per hour across eligible machine types in a specific region.

**Key Strategy:** The On-Demand "floor" of your ComputeClass should heavily bias toward machine families covered by your FlexCUDs.

### FlexCUD Coverage
- **Eligible:** Most general-purpose and compute-optimized families (e.g., `N2`, `N4`, `C3`, `C4`, `E2`, `N2D`).
- **Ineligible / Excluded:**
  - GPUs
  - TPUs
  - Local SSDs
  - Memory-optimized families (`M` series) (typically require resource-based CUDs)
  - Preemptible / Spot VMs
  - Sole-tenant nodes

### Priority List Design
When designing the `priorities[]` array for workloads that don't strictly require specialized hardware:
1.  **Spot Tier (Highest Priority):** Attempt to provision Spot VMs first. Spot is cheaper than FlexCUD On-Demand but is not covered by CUDs. Use `priorityScore` to tie-break across multiple Spot families based on unit cost. (Note: You can assign the same score to a maximum of 3 rules).
2.  **FlexCUD Tier (Middle Priority / Floor):** If Spot is unavailable, fall back to On-Demand families that are explicitly covered by your active FlexCUDs.
3.  **General On-Demand Tier (Lowest Priority - Optional):** If FlexCUD families are exhausted, fall back to other general-purpose On-Demand families (e.g., `E2`) to ensure obtainability.

### Example: Balancing Spot and FlexCUDs
```yaml
  priorities:
  # 1. Try Spot first across modern families
  - machineFamily: n4
    spot: true
    priorityScore: 100
  - machineFamily: c4
    spot: true
    priorityScore: 90
  # 2. Fallback to On-Demand covered by FlexCUD
  - machineFamily: n4
    spot: false
    # Assume N4 is covered by our regional FlexCUD commit
```

## Active Migration for Cost
Enable `activeMigration` to allow GKE to continuously move workloads to more cost-effective nodes as capacity becomes available.
```yaml
  activeMigration:
    optimizeRulePriority: true
```
- If a workload falls back to an On-Demand node (because Spot was unavailable), active migration will automatically evict the pod and move it to a Spot node when Spot capacity returns.
- **Throttling & Blocking Disruptions:** Active migration honors Pod Disruption Budgets (PDBs). Use PDBs to throttle the rate of eviction. If you need to completely stop active migration for specific critical pods, add the `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"` annotation to the pod spec.

## Balanced HA Scale-Up (Round-Robin)
If you need to achieve a roughly balanced, highly-available scale-up across multiple zones:
- Define separate priority rules (or use separate zonal node pools) for each zone.
- Assign an **equal `priorityScore`** to all of those zonal priority rules.
- GKE will evaluate them together and achieve a roughly balanced scale-up via round-robin selection.
