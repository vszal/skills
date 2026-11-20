# GKE ComputeClasses: Symptom-based troubleshooting

## Table of contents

- [First check: GKE version and observability telemetry](#first-check-gke-version-and-observability-telemetry): Lines 21-32
- [Symptom 1: ComputeClass config error](#symptom-1-computeclass-config-error): Lines 33-41
- [Symptom 2: Scale-up failure (pods pending)](#symptom-2-scale-up-failure-pods-pending): Lines 42-57
- [Symptom 3: Trapped in pending (GPU tolerations missing)](#symptom-3-trapped-in-pending-gpu-tolerations-missing): Lines 58-72
- [Symptom 4: Wrong nodes provisioned (E2 fallback trap)](#symptom-4-wrong-nodes-provisioned-e2-fallback-trap): Lines 73-80
- [Symptom 5: Active migration blocked](#symptom-5-active-migration-blocked): Lines 81-90
- [Symptom 6: ImageType fragmentation bug (pre-1.33.5)](#symptom-6-imagetype-fragmentation-bug-pre-1335): Lines 91-98
- [Symptom 7: Pods ignoring ComputeClass](#symptom-7-pods-ignoring-computeclass): Lines 99-104
- [Symptom 8: "ANY" reservation bypasses fallbacks](#symptom-8-any-reservation-bypasses-fallbacks): Lines 105-111
- [Symptom 9: Disk/PV attachment fail](#symptom-9-diskpv-attachment-fail): Lines 112-118
- [Symptom 10: Zonal PV deadlock (pending pods)](#symptom-10-zonal-pv-deadlock-pending-pods): Lines 119-125
- [Symptom 11: List loops / backoff](#symptom-11-list-loops--backoff): Lines 126-132
- [Symptom 12: Pods on low-priority nodes](#symptom-12-pods-on-low-priority-nodes): Lines 133-143
- [Symptom 13: Active migration thrash / continuous pod evictions (custom label sub-selection or stockout churn)](#symptom-13-active-migration-thrash--continuous-pod-evictions-custom-label-sub-selection-or-stockout-churn): Lines 144-158
- [Useful commands](#useful-commands): Lines 159-183

## First check: GKE version and observability telemetry

If fields are ignored or fail with "not supported," verify control-plane version floors first:

- **Verify CRD:** `kubectl describe crd computeclasses.cloud.google.com`
- **Check versions:** `gcloud container clusters describe <CLUSTER> --format="value(currentMasterVersion,currentNodeVersion)"`
- **Key floors:** `1.33.13+` (`ccc_priority_index` node annotation); `1.36.4-gke.1391000+` (`status.priorityStatuses[]`, `ProvisioningSuspended` / `ProvisioningConstrained` UTC backoff timers, and `com.google.cloud.v1.computeclasses.status` Cloud Audit Logs).

> **Observability & Forensics Reference:** For `status.priorityStatuses[]` schemas, authoritative condition tables (`ProvisioningSuspended`, `ProvisioningConstrained`, `CapacityConstrained`), live `kubectl` + `jq` backoff-remaining countdowns, Cloud Audit Log / Log Analytics SQL queries, `status.migration.configDrift`, and `k8s_entity` metrics, read [`compute-class-observability.md`](./compute-class-observability.md) and use `./assets/trace-pod-scaleup.sh`, `./assets/monitor-hard-stockouts.sh`, and `./assets/verify-minimum-capacity.sh`.

---

## Symptom 1: ComputeClass config error

Check `status.conditions` (`Health`, `CrdMisconfigured`) and `status.priorityStatuses[].conditions` (`RuleMisconfigured`) via `kubectl describe ComputeClass <NAME>`.

- **Common error:** `location config with specific reservations enabled`.
- **Fix:** Remove `location.zones` from the reservation priority — zones come from `reservations.specific[].zones` instead. Only `location.zones` collides; a policy-only `location.locationPolicy` (e.g. `BALANCED`) may remain.

---

## Symptom 2: Scale-up failure (pods pending)

Check `status.priorityStatuses[]` (`./assets/monitor-hard-stockouts.sh --ccc <name>`) and **Autoscaler Visibility logs** ([docs](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/cluster-autoscaler-visibility)):

- **Log filter:** `log_id("container.googleapis.com/cluster-autoscaler-visibility")`
- **Asset:** `assets/log-autoscaler-events.sh <cluster-name>` (Live tail).

| `messageId` | Meaning | Fix |
|---|---|---|
| `scale.up.error.out.of.resources` | GCE stockout | Add zone/family fallbacks. |
| `scale.up.error.quota.exceeded` | Project quota cap | Raise quota in target region. |
| `scale.up.error.ip.space.exhausted` | Subnet full | Expand subnet primary or Pod secondary CIDR ranges. |
| `scale.up.no.scale.up` | No priority matched | Check Pod requests vs shapes. |

---

## Symptom 3: Trapped in pending (GPU tolerations missing)

- **Symptom:** Pod requesting a GPU ComputeClass is stuck in `Pending` with `noScaleUp` logs.
- **Cause:** GKE auto-taints GPU nodes (`nvidia.com/gpu:NoSchedule`). Scheduler refuses placement without a toleration.
- **Fix:** Add toleration to pod spec:

  ```yaml
  tolerations:
  - key: "nvidia.com/gpu"
    operator: "Exists"
    effect: "NoSchedule"
  ```

---

## Symptom 4: Wrong nodes provisioned (E2 fallback trap)

- **Symptom:** Requested specific nodes (e.g., `C3` or `N4`), but GKE provisions default `E2` nodes.
- **Cause:** `whenUnsatisfiable: ScaleUpAnyway` provisions generic E2 nodes if preferred hardware fails. On GKE `1.33.13+`, these nodes carry `ccc_priority_index: "ccc_scale_up_anyway"`.
- **Fix:** Set `whenUnsatisfiable: DoNotScaleUp` to strictly enforce hardware list.

---

## Symptom 5: Active migration blocked

- **Symptom:** Spot capacity returned, but pods remain on On-Demand fallback nodes.
- **Cause:** PodDisruptionBudgets (PDBs) or `safe-to-evict: "false"` block voluntary eviction. Check `status.migration.configDrift` (`blockedNodes[]`) or `noDecisionStatus.noScaleDown` in visibility logs (see [`compute-class-observability.md`](./compute-class-observability.md)).
- **Fix:** Ensure PDBs allow at least 1 disruption (`maxUnavailable: 0` blocks migration).
- **Common GKE blocker — system-managed pods:** Non-DaemonSet pods in system namespaces (`kube-system`, `gke-managed-*`, `gmp-system`) often carry tight PDBs + low replicas, preventing source node drain. Check `kubectl get pdb -A`; raise replicas or isolate system pods onto a separate ComputeClass.
- **Note:** PDBs / `safe-to-evict` gate *voluntary* disruption only; Spot preemption is involuntary and bypasses both.

---

## Symptom 6: ImageType fragmentation bug (pre-1.33.5)

- **Symptom:** Autoscaler creates hundreds of tiny, fragmented node pools.
- **Cause:** Explicitly defining `imageType` (`ubuntu_containerd` or `cos_containerd`) on versions older than `1.33.5-gke.1862000` (and `1.34.1-gke.2541000`).
- **Fix:** Upgrade cluster or temporarily remove `imageType`.

---

## Symptom 7: Pods ignoring ComputeClass

- **Fixes:** Ensure pod has `nodeSelector: cloud.google.com/compute-class: <NAME>`. Translate non-GKE node selectors — generic/AWS-style `machine-family: c4` won't match; use GKE-native `cloud.google.com/machine-family: c4` (family) or `node.kubernetes.io/instance-type` (shape), or move the constraint into `priorities[]`. Verify manual pools carry both label and taint. Check whether Pod requests exceed priority bounds.

---

## Symptom 8: "ANY" reservation bypasses fallbacks

- **Cause:** `reservations.affinity: AnyBestEffort` consumes On-Demand capacity at the GCE layer before evaluating remaining ComputeClass priorities, preventing your intended fallback.
- **Fix:** Use `affinity: AnyThenFail` (GKE `1.36.0-gke.3204000+`) or `affinity: Specific` with named reservations.

---

## Symptom 9: Disk/PV attachment fail

- **Cause:** Mixing Gen 4 VMs (Hyperdisk) and Gen 2 (PD) in the same priority list.
- **Fix:** Do not mix generations for workloads with attached PVs, or (GKE `1.35.3-gke.1290000+`) back data PVs with built-in `dynamic-rwo` (`type: dynamic` + `use-allowed-disk-topology: "true"`), making the autoscaler disk-topology-aware so mixed-generation `priorities[]` skip incompatible shapes cleanly.

---

## Symptom 10: Zonal PV deadlock (pending pods)

- **Symptom:** StatefulSet pod is Pending because disk is in zone B while node is in zone A.
- **Fix:** Do not hardcode `location` in priorities. Use a `StorageClass` with `volumeBindingMode: WaitForFirstConsumer` (such as built-in `dynamic-rwo` on GKE `1.35.3-gke.1290000+`) so disks provision in the chosen node's zone.

---

## Symptom 11: List loops / backoff

- **Cause:** A long priority list (more than about 10 rules; keep ladders to 6–8, especially manual `priorities[].nodepools`). Unobtainable pools enter a 5-minute cooldown, and long lists expire upper-tier cooldowns before reaching the bottom, causing an infinite loop.
- **Fix:** Trim redundant rules and prefer `machineFamily` with `nodePoolAutoCreation.enabled: true` (which benefits from ComputeClass cumulative cooldown prolongation).

---

## Symptom 12: Pods on low-priority nodes

- **Symptom:** Pods land on existing low-priority nodes (e.g., On-Demand) instead of triggering scale-up for available high-priority nodes (e.g., Spot).
- **Cause:** ComputeClass controls *node provisioning*, not *pod scheduling*. `kube-scheduler` places pods on any existing node with spare capacity before invoking Cluster Autoscaler.
- **Fix:**
  1. **ActiveMigration:** Set `optimizeRulePriority: true` to drift workloads back to Priority 0 (avoid `min-nodes > 0` on fallback pools).
  2. **PriorityClass:** Use native K8s PriorityClass for pod-level preemption.
  3. **Kueue:** Use Kueue for batch/AI/ML fair-sharing and queueing.

---

## Symptom 13: Active migration thrash / continuous pod evictions (custom label sub-selection or stockout churn)

- **Symptom:** Nodes are repeatedly cordoned (`autoscaling.gke.io/defrag-candidate`), and pods experience voluntary evictions every ~5 minutes or get evicted laterally between nodes of the same priority without converging.
- **Root Cause 1 (Monolithic ComputeClass custom-label sub-selection combined with `activeMigration`):**
  - A single ComputeClass defines multiple priorities (e.g., Priority 0 = General Spot, Priority 1 = HighMem On-Demand) while workloads use custom `nodeSelector` labels (`priorities[].nodeLabels` or manual pool labels) to target Priority 1+. (Safe for scale-up when `optimizeRulePriority: false`, but causes continuous churn when `optimizeRulePriority: true`.)
  - Priority drift evaluation (`high_priority_migration.go:102-112`) treats **only index 0 as optimal** (`ccc_priority_index: "0"`). Any node with `ccc_priority_index > 0` is permanently classified as a defragmentation candidate and drained laterally or downward into existing headroom (`simulation.go:88-98`).
- **Root Cause 2 (Stockout backoff loop in CreateBeforeDelete mode):**
  - `optimizeRulePriority: true` with manual node pools (`nodePoolAutoCreation.enabled: false`) during sustained zonal stockouts (`ZONE_RESOURCE_POOL_EXHAUSTED`). Every 5 minutes when MIG backoff expires, `CreateBeforeDelete` (`defrag.go:53-55`) evicts candidate pods into existing spare cluster headroom before scale-up fails again ([Public Issue 445891977](https://issuetracker.google.com/issues/445891977)).
- **Fixes:**
  1. **Split into dedicated ComputeClasses per workload profile** so each workload's preferred shape/lifecycle is at **Priority 0** (`ccc_priority_index: "0"`).
  2. **Set `activeMigration.optimizeRulePriority: false` during sustained stockouts or peak events** to stop voluntary defragmentation evictions while preserving scale-up priority order.
  3. **Order Reservations above Spot:** Place Reserved On-Demand rules at Priority 0 above Spot.

---

## Useful commands

```bash
# Check all nodes and their ComputeClass priority annotations
kubectl get nodes \
  -o custom-columns=NAME:.metadata.name,CCC:.metadata.labels.cloud\.google\.com/compute-class,PRIORITY_INDEX:.metadata.annotations.ccc_priority_index,ZONE:.metadata.labels.topology\.kubernetes\.io/zone

# Check live priority statuses and backoff messages
kubectl get computeclasses -o json | jq '.items[] | {name: .metadata.name, statuses: .status.priorityStatuses}'

# List pods targeting a specific ComputeClass
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.nodeSelector["cloud.google.com/compute-class"]=="<name>") | .metadata.name'

# Cloud Logging: CA Visibility scale-up decisions
gcloud logging read 'log_id("container.googleapis.com/cluster-autoscaler-visibility") AND jsonPayload.decision.scaleUp:*' --limit=20

# Cloud Logging: CA Visibility stockouts and noScaleUp reasons
gcloud logging read 'log_id("container.googleapis.com/cluster-autoscaler-visibility") AND (jsonPayload.resultInfo.results.error.messageId="scale.up.error.out.of.resources" OR jsonPayload.noDecisionStatus.noScaleUp:*)' --limit=20

# Cloud Audit Logs: Historical ComputeClass status & backoff transitions (survives node scale-down)
gcloud logging read 'resource.type="k8s_cluster" AND protoPayload.methodName="com.google.cloud.v1.computeclasses.status" AND protoPayload.resourceName:"cloud.google.com/v1/computeclasses/<name>"' --limit=20

# Cloud Audit Logs: Historical ccc_priority_index node annotation patch (stamped ~60s post-create)
gcloud logging read 'resource.type="k8s_cluster" AND protoPayload.methodName=("io.k8s.core.v1.nodes.patch" OR "io.k8s.core.v1.nodes.update") AND protoPayload.resourceName:"nodes/<node-name>"' --limit=20
```
