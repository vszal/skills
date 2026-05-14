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

## Symptom 3: Trapped in Pending (GPU Tolerations Missing)
- **Symptom:** You request a GPU ComputeClass, but the pod is stuck in `Pending` and CA logs show `noScaleUp`. The node pool creates successfully if you do it manually.
- **Cause:** GKE automatically taints nodes with GPUs (`nvidia.com/gpu:NoSchedule`). While the CCC knows to create the node, the Kubernetes scheduler refuses to place your pod on it because your pod lacks the toleration.
- **Fix:** You MUST add this toleration to your pod spec for GPU CCCs:
    ```yaml
    tolerations:
    - key: "nvidia.com/gpu"
      operator: "Exists"
      effect: "NoSchedule"
    ```

## Symptom 4: Wrong Nodes Provisioned (The E2 Fallback Trap)
- **Symptom:** You requested specific nodes (e.g., `C3` or `N4`) in your `priorities`, but GKE keeps provisioning default `E2` nodes.
- **Cause:** Your `ComputeClass` is likely set to `whenUnsatisfiable: ScaleUpAnyway`. This tells GKE "if you can't find my preferred hardware, just give me generic E2 nodes so the pod can start."
- **Fix:** Change `whenUnsatisfiable` to `DoNotScaleUp` to strictly enforce your hardware list.

## Symptom 5: Active Migration is Blocked
- **Symptom:** You have `activeMigration: { optimizeRulePriority: true }` enabled. Spot capacity has returned, but pods are stuck on the expensive On-Demand fallback nodes.
- **Cause:** Pod Disruption Budgets (PDBs) are blocking the eviction. Active migration strictly honors PDBs.
- **Fix:** Check `kubectl get pdb`. Ensure your PDBs allow at least 1 disruption so CA can migrate the pods.

## Symptom 6: The ImageType Fragmentation Bug (Pre-1.33.5)
- **Symptom:** Autoscaler creates hundreds of tiny, fragmented node pools.
- **Cause:** On GKE versions older than 1.33.5-gke.1862000 (and 1.34.1-gke.2541000), explicitly defining `imageType: UBUNTU_CONTAINERD` (or COS) in a CCC causes a bug leading to excessive node pool creation.
- **Fix:** Upgrade your cluster, or temporarily remove the `imageType` field from your CCC.

## Symptom 7: Pods Ignoring CCC
1. **Selector Check:** Pod must have `nodeSelector: cloud.google.com/compute-class: <NAME>`.
2. **Conflicting Selectors:** Pod also pins `cloud.google.com/gke-spot` or `machine-family`. **Fix:** Move constraints into CCC.
3. **Manual Pool Taints:** Manual pool missing `cloud.google.com/compute-class` label/taint.
4. **Resources:** Pod requests (CPU/RAM) exceed every CCC priority's bounds.

## Symptom 8: "ANY" Reservation Bypassing Fallbacks
- **Cause:** `reservations.affinity: AnyBestEffort` falls back to On-Demand at the GCE layer.
- **Fix:** Use `affinity: Specific` with named reservations.

## Symptom 9: Disk/PV Attachment Fail
- **Cause:** Gen 4 VMs (Hyperdisk) vs Gen 2 (PD).
- **Fix:** Do not mix Gen 2 and Gen 4 in the same priority list for workloads with attached PVs.

## Symptom 10: Zonal PV Deadlock (Pending Pods)
- **Symptom:** A StatefulSet pod using standard Zonal Persistent Disks is stuck in Pending. The ComputeClass created a node in `us-central1-a`, but the disk is in `us-central1-b`.
- **Cause:** The PV already exists in a specific zone, but the autoscaler picked a different zone.
- **Fix:** Do **not** hardcode the `location` in the ComputeClass priorities, as this reduces obtainability. Instead, configure the **StorageClass** with `volumeBindingMode: WaitForFirstConsumer`. This forces the disk to be provisioned in the same zone where the Autoscaler decides to schedule the Pod.

## Symptom 11: List Loops / Backoff
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
