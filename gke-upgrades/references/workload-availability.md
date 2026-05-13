# Workload Availability During Upgrades

## Pod Disruption Budgets (PDBs) and Grace Periods
- **PDBs:** Define `minAvailable` or `maxUnavailable` to prevent too many pods from being evicted at once. 
- **1-Hour Limit:** GKE respects PDBs and `terminationGracePeriodSeconds` for a maximum of **1 hour** during node upgrades. After 60 minutes, GKE will **forcefully evict pods**, ignoring PDBs and grace periods, to proceed with the upgrade.
- **Batch Jobs:** If you have jobs running longer than an hour that cannot be safely interrupted, you must isolate them to a dedicated node pool. Use Maintenance Exclusions on that specific pool to prevent upgrades while the jobs are active.

## Stateful Workloads
- Upgrades can be extremely risky for stateful applications without graceful termination. Ensure proper node upgrade strategies are employed to avoid data corruption.
- Ensure `readinessProbes` are properly configured so pods are only marked ready when they can actually handle traffic after an upgrade.

## Control Plane Availability
- **Regional Clusters:** Use regional clusters (3 replicas of the control plane) to ensure API availability during KCP upgrades. 
- **Zonal Clusters:** Zonal clusters suffer KCP downtime during upgrades, blocking new deployments or mutating webhook requests.