# Maintenance Windows & Exclusions

## Maintenance Windows
Define recurring time slots when GKE is allowed to perform automated upgrades (e.g., Every Saturday from 00:00 to 04:00 UTC).
- **Strategy:** Align windows with off-peak hours (e.g., weekends for Dev to prevent CI/CD disruption, low-traffic nights for Prod).

## Maintenance Window Pausing
- If an upgrade takes longer than your defined maintenance window, GKE will pause the upgrade. This leaves your cluster in a **mixed-version state** (some nodes upgraded, some not) until the next window opens.
- **Resolution:** Do not leave clusters in a mixed-version state for extended periods. Either temporarily expand the maintenance window or manually resume the upgrade to completion:
  `gcloud container clusters upgrade [CLUSTER_NAME] --node-pool=[POOL_NAME] --location=[LOCATION]`

## Maintenance Exclusions
Define specific dates/times when upgrades are **forbidden** (e.g., `NO_UPGRADES`, `NO_MINOR_UPGRADES`).
- **Limits:** By default, standard maintenance exclusions can last a maximum of **32 days**.
- **Dynamic Exclusions for Batch Jobs:** For multi-week batch jobs that cannot be interrupted, PDBs are insufficient (GKE ignores PDBs after 1 hour). Instead, isolate these workloads to a dedicated node pool and dynamically create a `NO_UPGRADES` exclusion via automation before the job starts, deleting it once the job finishes.