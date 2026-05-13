# Troubleshooting Upgrades

## Monitoring Status
- **CLI:** `gcloud container operations list`
- **Logs:** Search Cloud Logging for `resource.type="gke_cluster"` and `jsonPayload.message:"Upgrade"` to find `UPGRADE_MASTER` and `UPGRADE_NODES` events.

## Common Failures & Recovery
- **Insufficient Quota:** Upgrade fails to provision surge/green nodes.
- **PDB Violations:** Upgrade stalls because PDBs prevent node draining (forces eviction after 1 hour).
- **Node Readiness:** New nodes fail to join the cluster (check firewall rules, networking).
- **Blue/Green Rollback Failure:** If the green pool fails health checks, GKE automatically rolls back. If the rollback stalls, intervene manually:
    - To force a rollback: `gcloud container node-pools rollback [NODE_POOL_NAME]`
    - To force completion: `gcloud container node-pools complete-upgrade [NODE_POOL_NAME]`
- **Manual Node Upgrade:** If auto-upgrade fails, try upgrading a single node pool manually to isolate issues.

## Networking (CNI) Troubleshooting
If you experience intermittent connectivity, DNS failures, or FQDN policy issues post-upgrade (often due to Dataplane V2/Cilium updates):
1. **Inspect `anetd` Logs:** Check the logs of the Cilium agent in the `kube-system` namespace on affected nodes:
   `kubectl logs -n kube-system -l k8s-app=cilium -c cilium-agent`
2. **Check for Drops:** Look for packet drop events or identity synchronization errors in the logs.
3. **Connectivity Test:** Use the GKE Connectivity Test tool to isolate whether the issue is internal cluster networking or external egress.