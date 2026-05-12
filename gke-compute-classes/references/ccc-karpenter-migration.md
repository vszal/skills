# CCC: Migrating from Karpenter

## Concept Mapping
| Karpenter | GKE ComputeClass | Note |
|-----------|------------------|------|
| `NodePool` | `ComputeClass` | Collapse multiple NodePools into `priorities[]`. |
| `spec.weight` | **Order in `priorities[]`** | Top wins. Strictly ordered traversal. |
| `instance-family In [m6i]` | `machineFamily: n4` | GCP equivalents: `m6i` -> `n4`, `c6i` -> `c4`. |
| `capacity-type: spot` | `spot: true` | Declare per priority. |
| `consolidateAfter: 30s` | `consolidationDelayMinutes: 1` | Floor is 1 minute. |
| `drift` | `activeMigration: { optimizeRulePriority: true }` | Honors PDBs. |
| `disruption.budgets` | **PodDisruptionBudget (PDB)** | Standard K8s resource. |

## Family Translation (AWS -> GCP)
- **General Purpose:** `m5/m6i` -> `n2 / n4`.
- **Compute Optimized:** `c5/c6i` -> `c2 / c4`.
- **AMD:** `m5a/m6a` -> `n2d / n4d`.
- **ARM:** `c7g/m7g` -> `c4a / n4a`.
- **Memory Optimized:** `r5/r6i` -> `n2-highmem / n4-highmem`.

## Key Behavioral Differences
- **Fast-fail Traversal:** CCC falls through to next priority immediately on failure. No probabilistic selection.
- **Spec Changes:** Updating CCC doesn't drift nodes automatically unless `activeMigration` is enabled.
- **Spot vs OD:** On GCP, Spot/OD often share capacity for CPU. Always include an OD floor.
- **No Topology in CCC:** Set `topologySpreadConstraints` on the Pod, not the CCC.
- **`whenUnsatisfiable`:** Karpenter's "any VM" doesn't match GKE's `ScaleUpAnyway` (which picks E2). Use `DoNotScaleUp` and accept `Pending`.
