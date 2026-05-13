# Resource & Capacity Constraints

## Quota
- Surge and Blue/Green upgrades require additional **Compute Engine CPU and IP quota**.
- Ensure your project has enough headroom, especially for large regional clusters.

## Resource-Constrained Pools (GPUs/TPUs)
- **No-Surge Upgrades:** For specialized hardware with tight quotas or cloud capacity exhaustion, use "No-Surge" upgrades (`maxSurge=0`, `maxUnavailable=1`) to avoid quota exhaustion. This forces GKE to delete a node before creating the new one.
  `gcloud container node-pools update [POOL_NAME] --cluster [CLUSTER_NAME] --max-surge-upgrade 0 --max-unavailable-upgrade 1`

## ComputeClasses for Capacity Constraints
- When upgrading node pools that rely on high-demand machine types, consider leveraging GKE ComputeClasses to define fallback capacity in case the primary instances are stocked out during the upgrade.