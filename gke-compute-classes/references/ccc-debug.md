# GKE ComputeClasses: Debugging

## First Check: GKE Version
If fields are ignored or fail with "not supported," the control plane is likely too old.
- **Verify CRD:** `kubectl describe crd computeclasses.cloud.google.com` (Authoritative).
- **Check Versions:** `gcloud container clusters describe <CLUSTER> --format="value(currentMasterVersion,currentNodeVersion)"`.
- **Reference:** [API docs](https://docs.cloud.google.com/kubernetes-engine/docs/reference/crds/computeclass) for "Available in GKE version" notes.

## Symptom 1: CCC Config Error
Check `status.conditions` on the ComputeClass object.
- **Command:** `kubectl describe ComputeClass <NAME>`
- **Common Error:** `location config with specific reservations enabled`.
- **Fix:** Omit `location` from the reservation priority. Set `reservations.specific[].zones` instead.

## Symptom 2: Scale-Up Failure (Pods Pending)
Check **Autoscaler Visibility logs** ([docs](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/cluster-autoscaler-visibility)).
- **Log Filter:** `log_id("container.googleapis.com/cluster-autoscaler-visibility")`
- **Asset:** `assets/log-autoscaler-events.sh <cluster-name>` (Live tail).

| `messageId` | Meaning | Fix |
|-------------|---------|-----|
| `scale.up.error.out.of.resources` | GCE stockout | Add zone/family fallbacks. |
| `scale.up.error.quota.exceeded` | Project quota cap | Raise quota in target region. |
| `scale.up.error.ip.space.exhausted` | Subnet full | Expand subnet ranges. |
| `scale.up.no.scale.up` | No priority matched | Check Pod requests vs CCC shapes. |

## Symptom 3: Pods Ignoring CCC
1. **Selector Check:** Pod must have `nodeSelector: cloud.google.com/compute-class: <NAME>`.
2. **Conflicting Selectors:** Pod also pins `cloud.google.com/gke-spot` or `machine-family`. **Fix:** Move constraints into CCC.
3. **Manual Pool Taints:** Manual pool missing `cloud.google.com/compute-class` label/taint.
4. **Resources:** Pod requests (CPU/RAM) exceed every CCC priority's bounds.

## Symptom 4: "ANY" Reservation Bypassing Fallbacks
- **Cause:** `reservations.affinity: AnyBestEffort` falls back to On-Demand at the GCE layer.
- **Fix:** Use `affinity: Specific` with named reservations.

## Symptom 5: Disk/PV Attachment Fail
- **Cause:** Gen 4 VMs (Hyperdisk) vs Gen 2 (PD).
- **Fix:** Do not mix Gen 2 and Gen 4 in the same priority list for workloads with attached PVs.

## Symptom 6: List Loops / Backoff
- **Cause:** Too many priorities (>10). Upper-tier backoffs expire before reaching the bottom.
- **Fix:** Trim the list; remove redundant rules.

## Useful Commands
```bash
# See which CCC nodes belong to
kubectl get nodes -L cloud.google.com/compute-class

# Find pods selecting a specific CCC
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.nodeSelector["cloud.google.com/compute-class"]=="<name>") | .metadata.name'

# Pull last 1h of autoscaler logs
gcloud logging read 'log_id("container.googleapis.com/cluster-autoscaler-visibility")' --freshness=1h --limit=50
```
