# ComputeClass: Cost optimization & FlexCUDs

## Table of contents

- [Aligning with Committed Use Discounts (CUDs)](#aligning-with-committed-use-discounts-cuds): Lines 9-63
- [Active migration for cost](#active-migration-for-cost): Lines 64-85
- [Balanced HA scale-up across zones](#balanced-ha-scale-up-across-zones): Lines 86-147

## Aligning with Committed Use Discounts (CUDs)

Before selecting machine families for your `priorities[]` list, you **must**
identify your existing Committed Use Discounts (CUDs) and Reservations.

**Key Strategy:** The On-Demand "floor" of your ComputeClass should heavily bias
toward machine families covered by your CUDs (Resource-based or Flexible).

### FlexCUD coverage

-   **Eligible:** Most general-purpose and compute-optimized families (e.g.,
    `N2`, `N4`, `C3`, `C4`, `E2`, `N2D`).
-   **Ineligible / Excluded:**
    -   GPUs
    -   TPUs
    -   Local SSDs
    -   Memory-optimized families (`M` series) (typically require resource-based
        CUDs)
    -   Preemptible / Spot VMs
    -   Sole-tenant nodes

### Priority list design

When designing the `priorities[]` array for workloads that don't strictly
require specialized hardware:

1.  **Spot Tier (Highest Priority):** Attempt to provision Spot VMs first. Spot
    is cheaper than FlexCUD On-Demand but is not covered by CUDs. Use
    `priorityScore` to tie-break across multiple Spot families based on unit
    cost. (Note: You can assign the same score to a maximum of 3 rules).
2.  **FlexCUD Tier (Middle Priority / Floor):** If Spot is unavailable, fall
    back to On-Demand families that are explicitly covered by your active
    FlexCUDs.
3.  **General On-Demand Tier (Lowest Priority - Optional):** If FlexCUD families
    are exhausted, fall back to other general-purpose On-Demand families (e.g.,
    `E2`) to ensure obtainability.

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
    priorityScore: 50  # if any rule sets priorityScore, every rule must
    # Assume N4 is covered by our regional FlexCUD commit
```

## Active migration for cost

Enable `activeMigration` to allow GKE to continuously move workloads to more
cost-effective nodes as capacity becomes available.

```yaml
  activeMigration:
    optimizeRulePriority: true
```

-   If a workload falls back to an On-Demand node (because Spot was
    unavailable), active migration will automatically evict the pod and move it
    to a Spot node when Spot capacity returns.
-   **Throttling Vol. Disruptions:** Active migration honors Pod Disruption
    Budgets (PDBs). Use PDBs to throttle eviction rates. To stop active
    migration for specific pods, add the
    `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"` annotation
    (adding it to a Deployment's pod template triggers a rolling restart; a PDB
    applies without one — see `compute-class-lifecycle.md`).
-   **WARNING:** PDBs and `safe-to-evict` only block *voluntary* scaler actions.
    They **cannot** block *involuntary* Spot VM preemptions.

## Balanced HA scale-up across zones

"Balanced" spans **two independent layers** — clarify which the user wants:

-   **Infrastructure (nodes):** `locationPolicy: BALANCED` spreads node scale-up
    roughly evenly across zones **within a single multi-zone node pool**
    (best-effort; **still scales up** if a zone is short; `ANY` packs one zone).
    It does **not** balance across separate single-zone node pools.
-   **Workload (pods):** `BALANCED` does **not** balance pods. Add pod
    `topologySpreadConstraints` (`maxSkew: 1`, `topologyKey:
    topology.kubernetes.io/zone`, `whenUnsatisfiable: DoNotSchedule` — default
    `ScheduleAnyway` won't enforce it) on the **workload** (see
    `gke-cluster-autoscaler`).

**Trap:** one unscored priority *per zone* does NOT balance — priorities are
sequential, so zone-a drains fully before zone-b is tried.

**Method A1 — true multi-zone node pool (`locationPolicy: BALANCED` balances
nodes across zones; works without `priorityScore`):**

-   **Open reservations (GKE `1.36.0-gke.3204000+`):** use
    `reservations.affinity: AnyThenFail` with `location.locationPolicy:
    BALANCED` and `location.zones: ['us-central1-a', 'us-central1-b',
    'us-central1-c']`. NAP creates **one multi-zone node pool** spanning all
    listed zones.
-   **Specific reservations with the same name in every zone (pre-1.36 too):**
    create GCE specific reservations with the **exact same name and identical
    machine properties** in each zone, then list them in a **single**
    `reservations.specific[]` entry (`name: <SHARED-RES-NAME>`,
    `zones: ['us-central1-a', 'us-central1-b', 'us-central1-c']`) with
    `location.locationPolicy: BALANCED`. NAP aggregates matching same-name
    zonal reservations into **one multi-zone node pool**.
-   **Schema rule:** do **not** put `location.zones` on a `Specific`-reservation
    priority (error: *location config with specific reservations enabled*) —
    zones come from `reservations.specific[].zones`; keep `locationPolicy` only
    in `location`.

**Method A2 — differently named specific reservations per zone (separate
`specific[]` entries in one priority):**

-   If existing zonal reservations already have **different names** (e.g.,
    `res-a`, `res-b`, `res-c`), put all three as separate
    `reservations.specific[]` entries inside **ONE** `priorities[]` rule (do
    not split into sequential per-zone priorities).
-   **Important NAP limitation:** each separate single-zone
    `reservations.specific[]` entry causes node pool auto-creation to create its
    own **single-zone node pool**. Because `locationPolicy: BALANCED` only
    balances MIGs belonging to the *same* node pool, it does **not** guarantee
    even spread across those separate pools (the price expander picks among them
    via random shuffle + group-creation penalty). Pair with pod-level
    `topologySpreadConstraints` (`maxSkew: 1`, `whenUnsatisfiable:
    DoNotSchedule`) to enforce even zonal distribution.
-   Asset: `balanced-reserved-zonal-compute-class.yaml`.

**Method B — equal `priorityScore` (GKE `1.35.2-gke.1842000+`; not balanced):**

-   Define separate per-zone priority rules and assign them an **equal
    `priorityScore`** (max 3 rules/score).
-   GKE evaluates them together via the autoscaler expander (lowest cost wins,
    with random tie-breaking when costs are equal). This is not round-robin and
    does not guarantee an even zonal spread; add pod `topologySpreadConstraints`
    when an even spread matters.
