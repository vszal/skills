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
