# GKE ComputeClasses: Debugging

## First Check: GKE Version
If fields are ignored or fail with "not supported," the control plane is likely too old.
- **Verify CRD:** `kubectl describe crd computeclasses.cloud.google.com`
- **Check Versions:** `gcloud container clusters describe <CLUSTER> --format="value(currentMasterVersion,currentNodeVersion)"`

## Symptom 1: ComputeClass Config Error
Check `status.conditions` on the ComputeClass object via `kubectl describe ComputeClass <NAME>`.
- **Common Error:** `location config with specific reservations enabled`.
- **Fix:** Omit `location` from the reservation priority. Use `reservations.specific[].zones` instead.

## Symptom 2: Scale-Up Failure (Pods Pending)
Check **Autoscaler Visibility logs** ([docs](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/cluster-autoscaler-visibility)).
- **Log Filter:** `log_id("container.googleapis.com/cluster-autoscaler-visibility")`
- **Asset:** `assets/log-autoscaler-events.sh <cluster-name>` (Live tail).

| `messageId` | Meaning | Fix |
|-------------|---------|-----|
| `scale.up.error.out.of.resources` | GCE stockout | Add zone/family fallbacks. |
| `scale.up.error.quota.exceeded` | Project quota cap | Raise quota in target region. |
| `scale.up.error.ip.space.exhausted` | Subnet full | Expand subnet ranges. |
| `scale.up.no.scale.up` | No priority matched | Check Pod requests vs shapes. |

## Symptom 3: Trapped in Pending (GPU Tolerations Missing)
- **Symptom:** Pod requesting a GPU ComputeClass is stuck in `Pending` with `noScaleUp` logs.
- **Cause:** GKE auto-taints GPU nodes (`nvidia.com/gpu:NoSchedule`). Scheduler refuses placement without a toleration.
- **Fix:** Add toleration to pod spec:
  ```yaml
  tolerations:
  - key: "nvidia.com/gpu"
    operator: "Exists"
    effect: "NoSchedule"
  ```

## Symptom 4: Wrong Nodes Provisioned (E2 Fallback Trap)
- **Symptom:** Requested specific nodes (e.g., `C3` or `N4`), but GKE provisions default `E2` nodes.
- **Cause:** `whenUnsatisfiable: ScaleUpAnyway` provisions generic E2 nodes to start the pod if preferred hardware fails.
- **Fix:** Set `whenUnsatisfiable: DoNotScaleUp` to strictly enforce hardware list.

## Symptom 5: Active Migration Blocked
- **Symptom:** Spot capacity returned, but pods stuck on On-Demand nodes.
- **Cause:** Pod Disruption Budgets (PDBs) block eviction. Active migration strictly honors PDBs.
- **Fix:** Ensure PDBs allow at least 1 disruption. `maxUnavailable: 0` blocks migration.

## Symptom 6: ImageType Fragmentation Bug (Pre-1.33.5)
- **Symptom:** Autoscaler creates hundreds of tiny, fragmented node pools.
- **Cause:** Explicitly defining `imageType: UBUNTU_CONTAINERD` (or COS) on versions older than 1.33.5-gke.1862000 (and 1.34.1-gke.2541000).
- **Fix:** Upgrade cluster or temporarily remove `imageType`.

## Symptom 7: Pods Ignoring ComputeClass
- **Fixes:** Ensure pod has `nodeSelector: cloud.google.com/compute-class: <NAME>`. Move conflicting constraints (e.g., `machine-family`) into ComputeClass. Verify manual pools have correct label/taint. Check if Pod requests exceed priority bounds.

## Symptom 8: "ANY" Reservation Bypasses Fallbacks
- **Cause:** `reservations.affinity: AnyBestEffort` falls back to On-Demand at GCE layer.
- **Fix:** Use `affinity: Specific` with named reservations.

## Symptom 9: Disk/PV Attachment Fail
- **Cause:** Mixing Gen 4 VMs (Hyperdisk) and Gen 2 (PD) in the same priority list.
- **Fix:** Do not mix generations for workloads with attached PVs.

## Symptom 10: Zonal PV Deadlock (Pending Pods)
- **Symptom:** StatefulSet pod is Pending because disk is in zone B but node is in zone A.
- **Fix:** Do **not** hardcode `location` in priorities. Configure `StorageClass` with `volumeBindingMode: WaitForFirstConsumer` so disk provisions in the chosen node's zone.

## Symptom 11: List Loops / Backoff
- **Cause:** >10 priorities. Unobtainable shapes enter a 5-minute cooldown. Long lists expire upper-tier cooldowns before reaching the bottom, causing an infinite loop.
- **Fix:** Trim list; remove redundant rules.

## Useful Commands
```bash
kubectl get nodes -L cloud.google.com/compute-class
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.nodeSelector["cloud.google.com/compute-class"]=="<name>") | .metadata.name'
gcloud logging read 'log_id("container.googleapis.com/cluster-autoscaler-visibility")' --freshness=1h --limit=50
```
