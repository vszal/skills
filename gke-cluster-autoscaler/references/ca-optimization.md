# CA: Optimization Profiles & Location Policies

## Autoscaling Profiles (Cluster-wide)
| Profile | Behavior | When to use |
|---------|----------|-------------|
| `balanced` (default) | Keeps spare capacity; conservative scale-down. | Latency-sensitive serving. |
| `optimize-utilization` | Aggressive packing; faster removal. | Cost-driven; Batch; **Golden Path**. |

- **Command:** `gcloud container clusters update <C> --autoscaling-profile=optimize-utilization`.

## Location Policies (`--location-policy`)
Controls node distribution across zones in regional clusters.
- **`BALANCED`**: Keeps node counts even across zones. Use for **HA workloads** / `topologySpreadConstraints`.
- **`ANY`**: Grabs capacity from any zone. **Best for Spot VMs** and scarce SKUs (maximizes obtainability).

## CCC `locationPolicy`
Set per-priority in a ComputeClass to control NAC distribution.
```yaml
priorities:
- machineFamily: n4
  spot: true
  location:
    locationPolicy: ANY # Spot preference
```

## Resource CUDs vs. Reservations
Understanding how cost savings apply to autoscaled capacity:
- **Committed Use Discounts (CUDs):** Automatically consumed by the Cluster Autoscaler. When the autoscaler provisions a node of a specific machine family (e.g., `n4`), it automatically consumes any available CUD for that family up to exhaustion. No explicit autoscaler, NAP, or CCC configuration is needed.
- **Reservations:** Unlike CUDs, capacity reservations are **not** automatically consumed. They must be explicitly targeted. You must configure consumption via the Node Pool API (for standard/manual pools) or via a ComputeClass `reservations` block (for Node Auto-Creation / NAC).
