# GKE ComputeClasses: Debugging and observability

## Table of contents

- [First check: GKE version](#first-check-gke-version): Lines 28-37
- [ComputeClass status and priority status schema (1.36.4+)](#computeclass-status-and-priority-status-schema-1364): Lines 38-91
- [Authoritative condition table](#authoritative-condition-table): Lines 92-112
- [Node annotation contract](#node-annotation-contract): Lines 113-136
- [Step-by-step recipe: Pod-to-node traceability](#step-by-step-recipe-pod-to-node-traceability): Lines 137-201
- [Step-by-step recipe: Hard stockout detection](#step-by-step-recipe-hard-stockout-detection): Lines 202-246
- [Step-by-step recipe: Active migration & config drift rollout stalls](#step-by-step-recipe-active-migration-config-drift-rollout-stalls): Lines 247-260
- [Step-by-step recipe: Reservation realization & spillover forensics](#step-by-step-recipe-reservation-realization-spillover-forensics): Lines 261-273
- [Step-by-step recipe: Minimum capacity (`minimumCapacity.targetNodeCount`) & floor protection (1.36.4-gke.1391000+)](#step-by-step-recipe-minimum-capacity-minimumcapacitytargetnodecount-floor-protection-1364-gke1391000): Lines 274-287
- [Symptom 1: ComputeClass config error](#symptom-1-computeclass-config-error): Lines 288-296
- [Symptom 2: Scale-up failure (pods pending)](#symptom-2-scale-up-failure-pods-pending): Lines 297-312
- [Symptom 3: Trapped in pending (GPU tolerations missing)](#symptom-3-trapped-in-pending-gpu-tolerations-missing): Lines 313-327
- [Symptom 4: Wrong nodes provisioned (E2 fallback trap)](#symptom-4-wrong-nodes-provisioned-e2-fallback-trap): Lines 328-335
- [Symptom 5: Active migration blocked](#symptom-5-active-migration-blocked): Lines 336-345
- [Symptom 6: ImageType fragmentation bug (pre-1.33.5)](#symptom-6-imagetype-fragmentation-bug-pre-1335): Lines 346-353
- [Symptom 7: Pods ignoring ComputeClass](#symptom-7-pods-ignoring-computeclass): Lines 354-359
- [Symptom 8: "ANY" reservation bypasses fallbacks](#symptom-8-any-reservation-bypasses-fallbacks): Lines 360-366
- [Symptom 9: Disk/PV attachment fail](#symptom-9-diskpv-attachment-fail): Lines 367-373
- [Symptom 10: Zonal PV deadlock (pending pods)](#symptom-10-zonal-pv-deadlock-pending-pods): Lines 374-380
- [Symptom 11: List loops / backoff](#symptom-11-list-loops-backoff): Lines 381-387
- [Symptom 12: Pods on low-priority nodes](#symptom-12-pods-on-low-priority-nodes): Lines 388-398
- [Useful commands](#useful-commands): Lines 399-423

## First check: GKE version

If fields are ignored or fail with "not supported," the control plane is likely too old.

- **Verify CRD:** `kubectl describe crd computeclasses.cloud.google.com`
- **Check versions:** `gcloud container clusters describe <CLUSTER> --format="value(currentMasterVersion,currentNodeVersion)"`
- **GKE 1.36.4-gke.1391000+:** Introduces granular `status.priorityStatuses[]`, `ccc_priority_index` node annotations, and explicit provisioning conditions (`ProvisioningSuspended`, `ProvisioningConstrained`).

---

## ComputeClass status and priority status schema (1.36.4+)

In GKE 1.36.4-gke.1391000+, GKE reports granular status per priority tier directly on the `ComputeClass` custom resource under `status.priorityStatuses[]`.

### Status schema breakdown

```yaml
status:
  # Cluster-level conditions for the ComputeClass resource
  conditions:
  - type: Health
    status: "True"
    lastTransitionTime: "2026-09-18T17:02:57Z"
    reason: Health
    message: "Crd is healthy."
  
  # Granular status per priority tier
  priorityStatuses:
  - identifier: "0"                     # Priority tier identifier ("0", "1", "2" matching spec.priorities)
    resourceInfo:                       # Allocation and utilization tracking for this tier
    - name: cpu
      unit: Cores
      currentCount: 2
      targetCount: 2
      currentUtilizationPercentage: 16
      measuredAt: "2026-09-18T17:06:52Z"
    - name: memory
      unit: GiB
      currentCount: 6
      targetCount: 6
      currentUtilizationPercentage: 11
      measuredAt: "2026-09-18T17:06:52Z"
    scalingEventsHistory:               # Aggregated scaling telemetry
      provisionedNodesCount: 1
      consolidatedNodesCount: 0
      migratedNodesCount: 0
      measuredSince: "2026-09-18T17:03:06Z"
      measuredAt: "2026-09-18T17:06:52Z"
    conditions:                         # Priority-specific lifecycle and backoff conditions
    - type: MinCapacityProvisioned
      status: "True"
      reason: ProvisioningComplete
      lastTransitionTime: "2026-09-18T17:05:12Z"
```

### Schema field definitions

- `identifier`: A string representing the priority this status applies to. For user-defined rules in `spec.priorities`, this matches the 0-based array index (`"0"`, `"1"`, `"2"`). If `whenUnsatisfiable: ScaleUpAnyway` is configured, GKE appends a synthetic `PriorityStatus` entry with `identifier: "ScaleUpAnyway"`.
- `configHash`: A SHA-256 hex digest (`priorityStatuses[].configHash` and top-level `status.configHash`) fingerprinting the active priority rule and spec to detect configuration drift.
- `resourceInfo`: Per-priority resource capacity and usage metrics (`cpu`, `memory`, `nvidia.com/gpu`, `google.com/tpu`) showing `currentCount`, `targetCount`, `unit` (`Cores`, `GiB`, `Cards`), `currentUtilizationPercentage`, and `measuredAt`.
- `scalingEventsHistory`: Lifecycle counters recording `provisionedNodesCount`, `consolidatedNodesCount`, and `migratedNodesCount` between `measuredSince` and `measuredAt`.

---

## Authoritative condition table

GKE Cluster Autoscaler reports priority-specific operational states via `status.priorityStatuses[].conditions[]`:

| Condition type | Severity | Scope | Meaning and autoscaler behavior |
|---|---|---|---|
| `ProvisioningSuspended` | High | Priority tier | The entire priority tier is in full backoff across all zones and shapes due to GCE capacity stockouts, quota caps, or repeated scale-up failures. The autoscaler skips this tier until the UTC backoff timestamp in `message` expires (`NodeProvisioning associated with this priority failed due to the <Reason> error. Backing off the priority until YYYY-MM-DD HH:MM:SS UTC.`). |
| `ProvisioningConstrained` | High / Medium | Partial / Zonal | Node pools associated with this priority failed scale-up in specific zones and entered backoff cooldown (`NodeProvisioning of the node pools associated with this priority failed due to the <Reason> error. In backoff until YYYY-MM-DD HH:MM:SS UTC.`). Healthy zones remain active on this priority. |
| `IpSpaceExhausted` | High | Priority tier / Subnet | Secondary Pod CIDR range in the VPC subnet is exhausted (`reason: IpSpaceExhausted`, `NodeProvisioning associated with this priority failed due to IpSpaceExhausted error. Backing off the priority until YYYY-MM-DD HH:MM:SS UTC.`). |
| `NodeProvisioningInProgress` | Info | Priority tier | The autoscaler has triggered node pool auto-creation or node scale-up with Compute Engine (`reason: PodPending`, `1 new nodes will be added with config: {NodePool: ..., MachineType: ..., Zones: ...}`). Cleared automatically once nodes join as Ready. |
| `MinCapacityProvisioning` | Info | Priority tier | Proactive `minimumCapacity.targetNodeCount` node provisioning has started (`reason: ProvisioningStarted`). |
| `MinCapacityProvisioned` | Info | Priority tier | Tracks proactive `minimumCapacity.targetNodeCount` fulfillment (`status: "False", reason: ProvisioningInProgress` during scale-up; `status: "True", reason: ProvisioningComplete` once floor is satisfied). |
| `RuleMisconfigured` | High | Priority tier | The priority configuration contains contradictory or unsupported parameters (for example, invalid sysctls, unsupported confidential VM flags, or missing disk topologies). |

> **Included Diagnostic Scripts (`assets/`):**
> - `./assets/trace-pod-scaleup.sh <pod-name> [namespace]`: Automates end-to-end pod-to-node scale-up tracing (`nodeSelector` -> `status.priorityStatuses[]` -> CA visibility logs -> node `ccc_priority_index`).
> - `./assets/monitor-hard-stockouts.sh [compute-class-name]`: Scans all ComputeClasses for active `ProvisioningSuspended`, `ProvisioningConstrained`, and `IpSpaceExhausted` conditions, UTC backoff expiration windows, and stuck `Pending` pods.
> - `./assets/verify-minimum-capacity.sh <compute-class-name>`: Audits `minimumCapacity.targetNodeCount`, `MinCapacityProvisioned`, and expected `min-nodes-fake-*` scale-down protection logs.

---

## Node annotation contract

When GKE provisions nodes via node auto-provisioning for a ComputeClass, it marks every node with:
- Label: `cloud.google.com/compute-class: <compute-class-name>`
- Annotation: `ccc_priority_index: "<value>"`

### Annotation values

| `ccc_priority_index` value | Meaning | Cause |
|---|---|---|
| `"0"`, `"1"`, `"2"`, etc. | Configured priority tier | The node was provisioned by the corresponding 0-based rule in `spec.priorities`. |
| `"ccc_scale_up_anyway"` | Unconstrained fallback | All defined priorities failed or were unavailable, and GKE provisioned a default node (typically E2) because `whenUnsatisfiable: ScaleUpAnyway` was configured. |
| `"ccc_no_rule_matching"` | Unmatched node pool | The node was provisioned into a pool that did not match an active priority rule, or belongs to a pre-existing manual pool. |
| `"ccc_deleted"` | Deleted priority rule | The node was provisioned by a priority rule that has since been deleted from `spec.priorities` (config drift). |

### Querying node placement across the cluster

```bash
kubectl get nodes \
  -o custom-columns=NAME:.metadata.name,CCC:.metadata.labels.cloud\.google\.com/compute-class,PRIORITY_INDEX:.metadata.annotations.ccc_priority_index,ZONE:.metadata.labels.topology\.kubernetes\.io/zone,TYPE:.metadata.labels.node\.kubernetes\.io/instance-type
```

---

## Step-by-step recipe: Pod-to-node traceability

Follow this end-to-end recipe (or run `./assets/trace-pod-scaleup.sh <pod-name> [namespace]`) to trace why a pending pod was placed on a specific node tier:

1. **Inspect pending pod phase and events:**
   ```bash
   kubectl get pod <pod-name> -n <namespace> -o wide
   kubectl get events -n <namespace> --field-selector involvedObject.name=<pod-name>
   ```
   Check for `TriggeredScaleUp`, `Scheduled`, or `FailedScaleUp`.

2. **Inspect referenced ComputeClass spec and priority statuses:**
   ```bash
   CC_NAME=$(kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.nodeSelector.cloud\.google\.com/compute-class}')
   kubectl get computeclass "$CC_NAME" -o yaml
   ```
   Map configured `spec.priorities` indices (`0`, `1`, `2`) to `status.priorityStatuses[]`. Check whether higher-priority tiers have `ProvisioningSuspended: True` or `ProvisioningConstrained: True`.

3. **Query Cluster Autoscaler Visibility logs:**
   ```bash
   gcloud logging read '
     log_id("container.googleapis.com/cluster-autoscaler-visibility")
     AND jsonPayload.resultInfo.results.decision.scaleUp:*
   ' --limit=10 --format="table(timestamp,jsonPayload.trigger,jsonPayload.resultInfo.results[0].decision.scaleUp)"
   ```
   Locate the scale-up decision referencing your pod's controller group and target node pool.

4. **Audit historical ComputeClass status updates in Cloud Audit Logs:**
   ```text
   resource.type="k8s_cluster"
   protoPayload.resourceName:"cloud.google.com/v1/computeclasses/<COMPUTECLASS_NAME>"
   protoPayload.methodName:"com.google.cloud.v1.computeclasses.status"
   ```
   Expand `protoPayload.request.status` in any returned entry to inspect historical snapshots of `status.conditions`, `status.priorityStatuses[].conditions`, `resourceInfo` (`targetCount > currentCount` for scale-up vs. `< currentCount` for scale-down), and `scalingEventsHistory` (`provisionedNodesCount` vs. `consolidatedNodesCount`). To audit historical node `ccc_priority_index` placement after nodes have been deleted/scaled down, query:
   ```text
   resource.type="k8s_cluster"
   protoPayload.methodName="io.k8s.core.v1.nodes.create"
   protoPayload.request.metadata.labels."cloud.google.com/compute-class"="<COMPUTECLASS_NAME>"
   ```

5. **Query Cloud Monitoring metrics (`k8s_entity`):**
   Available on GKE 1.36+, use `resource.labels.entity_type = "ComputeClass"` and `resource.labels.entity_name = "<CCC_NAME>"` (or `""` for non-ComputeClass activity):
   - `kubernetes.io/autoscaler/cluster_pending_pods_per_ccc`: Pending Pods awaiting provisioning (or `UnableToProvision`).
   - `kubernetes.io/autoscaler/cluster_node_provisioning_attempts_count_per_ccc`: Scale-up attempts initiated per ComputeClass.
     - **Async Rule**: Never subtract failures from attempts in real time; compare trends over a rolling window (`rate(10m)`).
   - `kubernetes.io/autoscaler/cluster_node_provisioning_failed_attempts_count_per_ccc`: Failed scale-ups grouped by `metric.labels.reason` (15 codes: `RESOURCE_POOL_EXHAUSTED` [maps to `OutOfResources` in CRD status], `QUOTA_EXCEEDED`, `IP_SPACE_EXHAUSTED`, `PERMISSIONS_ERROR`, `VM_EXTERNAL_IP_ACCESS_POLICY_CONSTRAINT`, `INVALID_RESERVATION`, `RESERVATION_NOT_FOUND`, `RESERVATION_NOT_READY`, `RESERVATION_CAPACITY_EXCEEDED`, `RESERVATION_INCOMPATIBLE`, `AUTOMATIC_RESERVATIONS_NOT_AVAILABLE`, `AUTOMATIC_RESERVATIONS_NO_CAPACITY`, `UNSUPPORTED_TPU_CONFIGURATION`, `GkePersistentOperationError`, `OTHER`).

6. **Verify provisioned node placement and annotation:**
   ```bash
   NODE_NAME=$(kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.nodeName}')
   kubectl get node "$NODE_NAME" -o jsonpath='
     Node: {.metadata.name}
     ComputeClass Label: {.metadata.labels.cloud\.google\.com/compute-class}
     Priority Index Annotation: {.metadata.annotations.ccc_priority_index}
     Instance Type: {.metadata.labels.node\.kubernetes\.io/instance-type}
     Zone: {.metadata.labels.topology\.kubernetes\.io/zone}
   '
   ```
   Interpret `ccc_priority_index`:
   - If `"0"`: Workload was provisioned on primary priority.
   - If `"1"` or `"2"`: Higher tiers were bypassed due to stockouts or constraints.
   - If `"ccc_scale_up_anyway"`: All priority tiers failed, and fallback node was created.

---

## Step-by-step recipe: Hard stockout detection

A hard stockout occurs when all priority rules fail simultaneously, leaving workloads stuck in `Pending`. Run `./assets/monitor-hard-stockouts.sh [compute-class-name]` or follow these steps:

1. **Check for suspended priority tiers:**
   ```bash
   kubectl get computeclasses -o json | jq -r '
     .items[] | {name: .metadata.name, priorities: [
       .status.priorityStatuses[]? | {
         id: .identifier,
         suspended: (.conditions[]? | select(.type=="ProvisioningSuspended" and .status=="True") | .message)
       }
     ]}
   '
   ```
   If all priority identifiers show active `ProvisioningSuspended` messages with `until YYYY-MM-DD HH:MM:SS UTC`, the class is completely backed off.

2. **Inspect stuck pods and Warning events:**
   ```bash
   kubectl get pods -A --field-selector=status.phase=Pending
   kubectl get events -A --field-selector reason=FailedScaleUp --sort-by='.metadata.creationTimestamp'
   ```
   Look for:
   `Warning FailedScaleUp: pod didn't trigger scale-up: all priority rules in backoff`
   or
   `Warning FailedScaleUp: GCE out of resources`

3. **Query Cluster Autoscaler Visibility logs for unhandled scale-up failures:**
   ```bash
   gcloud logging read '
     log_id("container.googleapis.com/cluster-autoscaler-visibility")
     AND (jsonPayload.resultInfo.results.error.messageId="scale.up.error.out.of.resources"
          OR jsonPayload.noDecisionStatus.noScaleUp:*)
   ' --limit=15 --format="json"
   ```
   Examine `unhandledPodGroups[].napFailureReasons[]` for specific stockout messages (`scale.up.error.out.of.resources`) and parameter details (machine shape and zone).

4. **Remediation actions:**
   - Add cross-family fallback rules in `spec.priorities` (for example, fallback from `n4` to `c4` or `c3d`).
   - Broaden zone options: ensure `location.zones` does not restrict scheduling to an exhausted zone.
   - For batch workloads, consider `whenUnsatisfiable: ScaleUpAnyway` if progress on default shapes is acceptable.
   - Request GCE regional quota increase if logs show `scale.up.error.quota.exceeded`.

---

## Step-by-step recipe: Active migration & config drift rollout stalls

When updating a ComputeClass spec or enabling `spec.activeMigration` to rebalance workloads back to Priority 0, node replacement can stall silently due to restrictive PodDisruptionBudgets (PDBs) or `safe-to-evict: false` annotations.

1. **Inspect `status.migration.configDrift`:**
   ```bash
   kubectl get computeclass <name> -o jsonpath='{.status.migration.configDrift}' | jq .
   ```
   Check `driftedNodes` vs. `currentNodes`, and inspect `blockedNodes[]` grouped by reason (`PodDisruptionBudget`, `BlockingPods`, `ReplacementUnavailable`, `MaxNodeDisruptionReached`).
2. **Distinguish planned migration from Spot preemption churn:**
   Compare `scalingEventsHistory.migratedNodesCount` (active defragmentation to higher priorities) against `consolidatedNodesCount` (low-utilization scale-down) in live status or Cloud Audit Logs (`protoPayload.request.status`).

---

## Step-by-step recipe: Reservation realization & spillover forensics

To verify whether workloads consumed paid GCE capacity reservations (`reservationAffinity: any` or specific reservations) or spilled over to On-Demand billing:

1. **Inspect reservation status conditions:**
   Check `status.priorityStatuses[0].conditions[]` (live or in Cloud Audit Logs) for `ReservationCapacityExceeded`, `ReservationNotFound`, `ReservationNotReady`, or `ReservationIncompatible`.
2. **Quantify On-Demand spillover:**
   Compare `resourceInfo.currentCount` on Priority `"0"` (Reserved) vs. Priority `"1"` (Unreserved On-Demand fallback).
3. **Query Cloud Monitoring MQL (`k8s_entity`):**
   Monitor `kubernetes.io/autoscaler/cluster_node_provisioning_failed_attempts_count_per_ccc` filtered by `metric.labels.reason =~ "RESERVATION_.*|AUTOMATIC_RESERVATIONS_.*"`.

---

## Step-by-step recipe: Minimum capacity (`minimumCapacity.targetNodeCount`) & floor protection (1.36.4-gke.1391000+)

When configuring `spec.priorities[].minimumCapacity.targetNodeCount`, GKE proactively provisions warm floor nodes even with zero workload pods (`./assets/verify-minimum-capacity.sh <compute-class-name>`):

1. **Inspect `MinCapacityProvisioning` and `MinCapacityProvisioned` conditions:**
   ```bash
   kubectl get computeclass <name> -o jsonpath='{.status.priorityStatuses[0].conditions}' | jq .
   ```
   During proactive scale-up, `MinCapacityProvisioning` (`reason: ProvisioningStarted`) and `MinCapacityProvisioned: False` (`reason: ProvisioningInProgress`) appear. Once satisfied, `MinCapacityProvisioned: True` (`reason: ProvisioningComplete`) is set and `resourceInfo` shows `currentCount == targetCount` with `currentUtilizationPercentage: 0`.
2. **Understand `min-nodes-fake-*` and `no.scale.down.node.no.place.to.move.pods` (WAI):**
   To prevent idle floor nodes from being consolidated by Cluster Autoscaler, GKE injects synthetic floor placeholder pods (`min-nodes-fake-0`, `min-nodes-fake-1`) during scale-down simulation. In `container.googleapis.com/cluster-autoscaler-visibility` logs, these nodes report `noScaleDown` with `messageId: "no.scale.down.node.no.place.to.move.pods"` and `parameters: ["min-nodes-fake-0"]`. This is **working as intended (WAI)** floor protection, NOT a pod eviction or PDB issue.

---

## Symptom 1: ComputeClass config error

Check `status.conditions` on the ComputeClass object via `kubectl describe ComputeClass <NAME>`.

- **Common error:** `location config with specific reservations enabled`.
- **Fix:** Remove `location.zones` from the reservation priority — zones come from `reservations.specific[].zones` instead. Only `location.zones` collides; a policy-only `location.locationPolicy` (e.g. `BALANCED`) may remain.

---

## Symptom 2: Scale-up failure (pods pending)

Check **Autoscaler Visibility logs** ([docs](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/cluster-autoscaler-visibility)).

- **Log filter:** `log_id("container.googleapis.com/cluster-autoscaler-visibility")`
- **Asset:** `assets/log-autoscaler-events.sh <cluster-name>` (Live tail).

| `messageId` | Meaning | Fix |
|---|---|---|
| `scale.up.error.out.of.resources` | GCE stockout | Add zone/family fallbacks. |
| `scale.up.error.quota.exceeded` | Project quota cap | Raise quota in target region. |
| `scale.up.error.ip.space.exhausted` | Subnet full | Expand subnet ranges. |
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
- **Cause:** `whenUnsatisfiable: ScaleUpAnyway` provisions generic E2 nodes to start the pod if preferred hardware fails. In GKE 1.36.4+, these nodes carry `ccc_priority_index: "ccc_scale_up_anyway"`.
- **Fix:** Set `whenUnsatisfiable: DoNotScaleUp` to strictly enforce hardware list.

---

## Symptom 5: Active migration blocked

- **Symptom:** Spot capacity returned, but pods stuck on On-Demand nodes.
- **Cause:** Pod Disruption Budgets (PDBs) block eviction. Active migration strictly honors PDBs.
- **Fix:** Ensure PDBs allow at least 1 disruption. `maxUnavailable: 0` blocks migration.
- **Common GKE blocker — system-managed pods:** Non-DaemonSet pods in system namespaces (`kube-system`, `gke-managed-*`, `gmp-system`) often carry tight PDBs + low replicas, so the source node cannot drain (also blocks ordinary scale-down). Check `kubectl get pdb -A` and the autoscaler `noScaleDown` reason; raise replicas to add PDB headroom or isolate them onto a separate ComputeClass.
- **Note:** PDBs / `safe-to-evict` only gate *voluntary* disruption; Spot preemption is involuntary and ignores both.

---

## Symptom 6: ImageType fragmentation bug (pre-1.33.5)

- **Symptom:** Autoscaler creates hundreds of tiny, fragmented node pools.
- **Cause:** Explicitly defining `imageType: UBUNTU_CONTAINERD` (or COS) on versions older than 1.33.5-gke.1862000 (and 1.34.1-gke.2541000).
- **Fix:** Upgrade cluster or temporarily remove `imageType`.

---

## Symptom 7: Pods ignoring ComputeClass

- **Fixes:** Ensure pod has `nodeSelector: cloud.google.com/compute-class: <NAME>`. Translate non-GKE node selectors — a generic/AWS-style `machine-family: c4` won't match; use GKE-native `cloud.google.com/machine-family: c4` (family) or `node.kubernetes.io/instance-type` (shape), or better, move the constraint into the ComputeClass `priorities[]`. Verify manual pools have correct label/taint. Check if Pod requests exceed priority bounds.

---

## Symptom 8: "ANY" reservation bypasses fallbacks

- **Cause:** `reservations.affinity: AnyBestEffort` consumes On-Demand capacity at the GCE layer before evaluating your remaining ComputeClass priorities, preventing your intended fallback.
- **Fix:** Use `affinity: AnyThenFail` (GKE 1.36.0-gke.3204000+) or `affinity: Specific` with named reservations.

---

## Symptom 9: Disk/PV attachment fail

- **Cause:** Mixing Gen 4 VMs (Hyperdisk) and Gen 2 (PD) in the same priority list.
- **Fix:** Do not mix generations for workloads with attached PVs. Or (GKE 1.35.3-gke.1290000+): back the data PVs with the built-in `dynamic-rwo` StorageClass (`type: dynamic` + `use-allowed-disk-topology: "true"`) — the autoscaler becomes disk-topology-aware and scales up only compatible nodes, so a mixed-generation `priorities[]` no longer attach-fails.

---

## Symptom 10: Zonal PV deadlock (pending pods)

- **Symptom:** StatefulSet pod is Pending because disk is in zone B but node is in zone A.
- **Fix:** Do not hardcode `location` in priorities. Use a `StorageClass` with `volumeBindingMode: WaitForFirstConsumer` so the disk provisions in the chosen node's zone — the built-in `dynamic-rwo` (GKE 1.35.3-gke.1290000+) already sets this plus `use-allowed-disk-topology: "true"`.

---

## Symptom 11: List loops / backoff

- **Cause:** More than 10 priorities. Unobtainable shapes enter a 5-minute cooldown. Long lists expire upper-tier cooldowns before reaching the bottom, causing an infinite loop.
- **Fix:** Trim list; remove redundant rules.

---

## Symptom 12: Pods on low-priority nodes

- **Symptom:** Pods land on existing low-priority nodes (e.g., On-Demand) instead of triggering scale-up for available high-priority nodes (e.g., Spot).
- **Cause:** ComputeClass controls *node provisioning*, not *pod scheduling*. K8s schedules pods on any existing node with capacity before scaling up.
- **Fix:**
  1. **ActiveMigration:** Set `optimizeRulePriority: true` to eventually move workloads to higher-priority nodes.
  2. **PriorityClass:** Use native K8s PriorityClass for pod-level preemption.
  3. **Kueue:** Use Kueue for complex batch/AI/ML fair-sharing and queueing.

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
gcloud logging read 'log_id("container.googleapis.com/cluster-autoscaler-visibility") AND jsonPayload.resultInfo.results.decision.scaleUp:*' --limit=20

# Cloud Logging: CA Visibility stockouts and errors
gcloud logging read 'log_id("container.googleapis.com/cluster-autoscaler-visibility") AND (jsonPayload.resultInfo.results.error.messageId="scale.up.error.out.of.resources" OR jsonPayload.noDecisionStatus.noScaleUp:*)' --limit=20

# Cloud Audit Logs: Historical ComputeClass status transitions (survives node scale-down)
gcloud logging read 'resource.type="k8s_cluster" AND protoPayload.methodName="com.google.cloud.v1.computeclasses.status" AND protoPayload.resourceName:"cloud.google.com/v1/computeclasses/<name>"' --limit=20

# Cloud Audit Logs: Historical node creation and ccc_priority_index placement (survives node scale-down)
gcloud logging read 'resource.type="k8s_cluster" AND protoPayload.methodName="io.k8s.core.v1.nodes.create" AND protoPayload.request.metadata.labels."cloud.google.com/compute-class"="<name>"' --limit=20
```
