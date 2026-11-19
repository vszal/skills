# Cluster Autoscaler: Optimization Profiles & Location Policies

## Autoscaling Profiles (Cluster-wide)
| Profile | Behavior | When to use |
|---------|----------|-------------|
| `balanced` (default) | Keeps spare capacity; conservative scale-down. | Latency-sensitive serving. |
| `optimize-utilization` | Aggressive packing; faster removal. | Cost-driven; Batch; **Golden Path**. |

- **Command:** `gcloud container clusters update <C> --autoscaling-profile=optimize-utilization`.

## Spot Best Practices
- **Mandatory Fallback:** Any time you recommend or debug the use of Spot instances (whether via manual pools or node pool auto-creation), suggest including other Spot or On-Demand fallback priorities via ComputeClasses. Spot capacity is highly variable, and without a fallback, workloads will become stuck during GCE stockouts (`scale.up.error.out.of.resources`).

## Location Policies (`--location-policy`)

- **`BALANCED`**: Best-effort even **node** spread across zones *at scale-up* (infrastructure layer; still scales up if a zone is short). Does **not** balance **pods** — that's a separate workload layer needing pod `topologySpreadConstraints` (`DoNotSchedule`, see PTS below). The two are independent. Use for **HA workloads**.
- **`ANY`**: Grabs capacity from any zone. **Best for Spot VMs** and scarce SKUs (maximizes obtainability).

## ComputeClass `locationPolicy`

```yaml
priorities:
- machineFamily: n4
  spot: true
  location:
    locationPolicy: ANY # Spot preference
```

## Pod Topology Spread Constraints (PTS)
Cluster Autoscaler supports PTS for zonal spreading during scale-up.

To enforce spreading via autoscaler, you **MUST** use `whenUnsatisfiable: DoNotSchedule`.

Example Configuration:
```yaml
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: "topology.kubernetes.io/zone"
    whenUnsatisfiable: DoNotSchedule  # Required for cluster autoscaler compatibility
    labelSelector:
      matchLabels:
        app: my-app
```

## Resource CUDs vs. Reservations

- **Committed Use Discounts (CUDs) — ALWAYS state BOTH contrasts vs. Reservations:** (1) Reservations only reserve zonal capacity at On-Demand billing rates and do not reduce cost unless paired with a CUD; (2) **Unlike zonal, exact-shape reservations, CUDs automatically apply across any machine shape or zone of the matching machine family (e.g., `c3`, `n4`) across the entire region with zero node pool, zone, shape, or ComputeClass configuration.**
- **Reservations (Automatically Consumed `any` vs. Specific):**
  - *Default `any` (`ANY_RESERVATION`) behavior on Standard GKE (no node recreation needed for open reservations)*: Omitting `--reservation-affinity` on a **Standard (non-Autopilot)** node pool (or omitting `reservations:` on a Standard `ComputeClass` priority) leaves Compute Engine affinity at default `any` *(on Autopilot clusters or `spec.autopilot.enabled: true` ComputeClasses, omitted non-TPU affinity defaults to `NO_RESERVATION`)*. Under `any` affinity, both newly provisioned On-Demand nodes and already-running On-Demand nodes automatically bind in place to **automatically consumed (open)** reservations (`specificReservationRequired: false`) **if and only if** all hardware and scheduling properties match identically (`machineType`, exact `zone`, `minCpuPlatform`, `GPU type/count`, local SSD count/interface, `no compact placement policy` since compact placement requires `Specific` reservations, and non-Spot provisioning model).
  - *Why a reservation stays unused & when explicit targeting is required*: (1) **Specific reservations** (`--require-specific-reservation` / `specificReservationRequired: true`) **never** bind to default-affinity nodes and strictly require `--reservation-affinity=specific --reservation=<NAME>` or `ComputeClass` `reservations.affinity: Specific` + `specific[]` (since node pool `--reservation-affinity` is immutable, attaching existing running nodes to a Specific reservation requires node recreation); (2) **Autopilot `NO_RESERVATION` default** when `reservations` is omitted; (3) **Regional zone / `machineFamily` mismatch**: Cluster Autoscaler does not steer untargeted regional or `machineFamily` scale-ups into a reservation's zone or exact machine shape; (4) **Property mismatch, compact placement, or Spot VMs**: `minCpuPlatform` (`Automatic` vs. pinned CPU platform), GPU/local SSD mismatch, compact placement policy, or Spot VMs prevent open binding; (5) **Preserving ComputeClass fallbacks**: default `any` / `AnyBestEffort` falls back to unreserved On-Demand before stepping down `priorities[]`—use `AnyThenFail` (GKE `1.36.0-gke.3204000+`) or `Specific` to skip On-Demand when reserved slots fill.
- **Freshly-created reservations (cache lag):** The autoscaler caches reservation data and does **not** see a new reservation immediately. Driving scale-up against a brand-new reservation while Cluster Autoscaler's cache is stale makes Cluster Autoscaler fail to find the capacity and **back off that reservation** — which delays retries and compounds the stall. **Fix:** wait **at least 30 minutes** after creating a reservation before relying on it for autoscaler-driven scale-up. (Applies to the reservation itself; growing an existing, already-cached reservation is fine.)

## ComputeClass Fallback Dynamics

- **Backoff Hierarchy & Scopes**:
  - *ComputeClass Priority Cooldown*: Fixed 5-minute cooldown on declarative rules (`machineFamily`, `machineType`). Reset and prolonged when lower priorities fail subsequently, pushing the autoscaler toward the first obtainable priority without restarting from the top. The final priority rule is never backed off.
  - *Zonal vs Regional Scope*: In GKE versions prior to `1.36.3-gke.1244000`, a hard stockout puts the whole priority tier on a ~5-minute **regional** cooldown. Starting in GKE `1.36.3-gke.1244000+`, stockouts are scoped **strictly to the failing zone**, while healthy zones remain active on preferred tiers (quota errors remain regional).
  - *Standard MIG Backoff*: Exponential backoff (5m -> 10m -> 20m -> 30m, 3h reset) applied per single zone/MIG on manual node pools and `priorities[].nodepools`.
- **Manual Node Pools vs Node Pool Auto-Creation**:
  - Manual pools referenced via `priorities[].nodepools` do not benefit from cooldown prolongation. Large lists (>6–8 manual pools) cause early MIG backoffs to expire during simulation, restarting at the top in a loop.
  - Transition to declarative `machineFamily` rules with `nodePoolAutoCreation.enabled: true` for clean fallback progression.
- **`flexStart` Placement**:
  - DWS Flex Start queuing latency (3–15+ min) can allow higher-tier backoffs to expire during the queue wait. Always place `flexStart: true` at the very end of `priorities[]`.
- **GKE 1.36+ Synchronous Capacity Checking**:
  - Starting in GKE 1.36, Cluster Autoscaler checks internal capacity obtainability synchronously in memory before issuing VM creation requests, skipping exhausted families without tripping GCE API errors or backoff cooldowns.

