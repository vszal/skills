# GKE ComputeClasses: Observability, status conditions, and backoff forensics

## Table of contents

- [Version floors and telemetry surfaces](#version-floors-and-telemetry-surfaces): Lines 16-30
- [ComputeClass status and priority status schema (1.36.4+)](#computeclass-status-and-priority-status-schema-1364): Lines 31-80
- [Authoritative condition table](#authoritative-condition-table): Lines 81-95
- [Node annotation contract (`ccc_priority_index`)](#node-annotation-contract-ccc_priority_index): Lines 96-113
- [Recipe 1: Pod-to-node scale-up traceability](#recipe-1-pod-to-node-scale-up-traceability): Lines 114-151
- [Recipe 2: Hard stockout detection](#recipe-2-hard-stockout-detection): Lines 152-178
- [Recipe 3: Backoff time remaining and post-incident latency](#recipe-3-backoff-time-remaining-and-post-incident-latency): Lines 179-230
- [Recipe 4: Active migration and config drift stalls](#recipe-4-active-migration-and-config-drift-stalls): Lines 231-245
- [Recipe 5: Reservation realization and spillover forensics](#recipe-5-reservation-realization-and-spillover-forensics): Lines 246-254
- [Recipe 6: Minimum capacity floor verification (`min-nodes-fake-*`)](#recipe-6-minimum-capacity-floor-verification-min-nodes-fake-): Lines 255-259

## Version floors and telemetry surfaces

| Telemetry surface | Minimum GKE version | Primary role |
|---|---|---|
| **Node annotation (`ccc_priority_index`)** | `1.33.13+` | Stamps each auto-created node (~60s post-create via node patch/update) with the 0-based `spec.priorities` index or fallback sentinel. |
| **CRD `status.priorityStatuses[]` & conditions** | `1.36.4-gke.1391000+` | Live per-priority capacity counts, scaling event counters, active provisioning state, and UTC backoff expiration timestamps. |
| **Cloud Audit Logs (`computeclasses.status`)** | `1.36.4-gke.1391000+` | Historical status transitions (`cloudaudit.googleapis.com/activity`, flushed every ~30s), retaining backoff timers after live conditions clear. |
| **Config drift status (`status.migration.configDrift`)** | `1.36.4-gke.1391000+` (Oct 2026+ rollout) | Partitions ComputeClass nodes into `currentNodes`, `driftedNodes`, `migratingNodes`, and `blockedNodes[]` by blocker reason. |
| **Cloud Monitoring `k8s_entity` (`*_per_ccc`)** | `1.36.4-gke.1391000+` / `1.37+` rollout | Fleet-wide pending pods, provisioning attempts, and failed attempts grouped by 15 official `metric.labels.reason` codes. |

> **Included Diagnostic Scripts (`assets/`):**
> - `./assets/trace-pod-scaleup.sh --pod <pod-name> [--namespace <ns>]`: Correlates Pod `nodeSelector`, `status.priorityStatuses[]`, visibility logs, and `ccc_priority_index`.
> - `./assets/monitor-hard-stockouts.sh --ccc <compute-class-name>`: Scans active `ProvisioningSuspended` and `ProvisioningConstrained` conditions, computes applied and remaining backoff timers, and lists stuck `Pending` pods.
> - `./assets/verify-minimum-capacity.sh --ccc <compute-class-name>`: Audits `minimumCapacity.targetNodeCount`, `MinCapacityProvisioned`, and expected `min-nodes-fake-*` floor protection logs.

## ComputeClass status and priority status schema (1.36.4+)

In GKE `1.36.4-gke.1391000+`, GKE reports class-wide health in `status.conditions[]` (`Health`, `CrdMisconfigured`, `UnableToProvision`) and per-priority state under `status.priorityStatuses[]`:

```yaml
status:
  conditions:
  - type: Health
    status: "True"
    lastTransitionTime: "2026-09-18T17:02:57Z"
    reason: Health
    message: "Crd is healthy."
  priorityStatuses:
  - identifier: "0"                     # 0-based index in spec.priorities[]
    configHash: "a1b2c3..."             # SHA-256 rule fingerprint
    resourceInfo:                       # Array of named resources (query by .name)
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
    scalingEventsHistory:
      provisionedNodesCount: 1
      consolidatedNodesCount: 0
      migratedNodesCount: 0
      measuredSince: "2026-09-18T17:03:06Z"
      measuredAt: "2026-09-18T17:06:52Z"
    conditions:
    - type: MinCapacityProvisioned
      status: "True"
      reason: ProvisioningComplete
      lastTransitionTime: "2026-09-18T17:05:12Z"
```

### Schema field definitions

- `identifier`: Matches the 0-based index in `spec.priorities` (`"0"`, `"1"`, `"2"`). When `whenUnsatisfiable: ScaleUpAnyway` is configured, GKE appends **two** extra entries: an implicit numeric rung at `str(len(spec.priorities))` carrying active fallback provisioning conditions (`NodeProvisioningInProgress`), and a synthetic entry with `identifier: "ScaleUpAnyway"`. Never index `spec.priorities[int(identifier)]` without bounds-checking `int(identifier) < len(spec.priorities)`.
- `configHash`: SHA-256 hex digest (`priorityStatuses[].configHash` and top-level `status.configHash`) fingerprinting the active rule to detect configuration drift.
- `resourceInfo`: Array of resource objects (`cpu`, `memory`, `ephemeral-storage`, `nvidia.com/gpu`, `google.com/tpu`) with `currentCount`, `targetCount`, `unit` (`Cores`, `GiB`, `Cards`), `currentUtilizationPercentage`, and `measuredAt`. Select entries by `.name` (for example, `.resourceInfo[] | select(.name=="cpu") | .currentCount`).
- `scalingEventsHistory`: Lifecycle counters (`provisionedNodesCount`, `consolidatedNodesCount`, `migratedNodesCount`) between `measuredSince` and `measuredAt` (reset on `spec.priorities` modification or autoscaler restart).

---

## Authoritative condition table

| Condition type | Severity | Scope | Meaning and autoscaler behavior |
|---|---|---|---|
| `ProvisioningSuspended` | High | Priority tier | Entire priority tier is unavailable across all zones and shapes (`reason`: `OutOfResources`, `QuotaExceeded`, `IpSpaceExhausted`, `ReservationCapacityExceeded`, `InvalidReservation`, `VmExternalIpAccessPolicyConstraint`, `InternalError`, or `CapacityConstrained`). Reactive failures embed a UTC expiration timestamp: `NodeProvisioning associated with this priority failed due to the <Reason> error. Backing off the priority until YYYY-MM-DD HH:MM:SS UTC.` Proactive synchronous capacity filtering (`reason: CapacityConstrained`) emits `No matching configuration is available (0/N available) due to active capacity cooldowns across requested zones.` with **no `until` timestamp** because Compute Engine availability is re-polled every `10–20s`. |
| `ProvisioningConstrained` | High / Medium | Partial / Zonal | Specific zones or shapes in this priority are unavailable while healthy zones/shapes remain active (`reason` values match `ProvisioningSuspended`). Reactive message: `NodeProvisioning of the node pools associated with this priority failed due to the <Reason> error. In backoff until YYYY-MM-DD HH:MM:SS UTC.` (when multiple zones/pools in the priority are in backoff simultaneously, `until` reports `max(until)`). For `reason: CapacityConstrained`, `message` reports `A subset (M/N) of configurations are excluded due to active capacity cooldowns across requested zones.` with no fixed `until` timestamp. |
| `NodeProvisioningInProgress` | Info | Priority tier | Autoscaler requested new nodes (`reason`: `PodPending`, `ActiveMigration`, `MinimumCapacity`, `CapacityBuffer`, `ProvisioningRequest`, `CapacityRequest`, `NodePoolMinSize`; `1 new nodes will be added with config: {NodePool: ..., MachineType: ..., Zones: ...}`). Cleared automatically once nodes join as Ready. |
| `MinCapacityProvisioning` | Info | Priority tier | Proactive `minimumCapacity.targetNodeCount` node provisioning started (`reason: ProvisioningStarted`). |
| `MinCapacityProvisioned` | Info | Priority tier | Tracks `minimumCapacity.targetNodeCount` fulfillment (`status: "False", reason: ProvisioningInProgress` during scale-up; `status: "True", reason: ProvisioningComplete` once floor is met). |
| `RuleMisconfigured` | High | Priority tier | Priority rule contains contradictory or unsupported parameters (invalid sysctls, unsupported confidential VM flags, unavailable machine type in zone). |

> **Note on `IpSpaceExhausted`:** Subnet primary VM IP or secondary Pod CIDR exhaustion surfaces as `reason: IpSpaceExhausted` under `ProvisioningConstrained` (single subnet/pool full) or `ProvisioningSuspended` (shared subnet full across the tier), not as a separate condition `type`. Fallback priorities sharing the same exhausted VPC subnet will also fail.

---

## Node annotation contract (`ccc_priority_index`)

On GKE `1.33.13+`, every node provisioned for a ComputeClass receives label `cloud.google.com/compute-class: <name>` and bare annotation `ccc_priority_index` (no `cloud.google.com/` prefix, stamped ~60s post-creation):

| `ccc_priority_index` value | Meaning | Cause |
|---|---|---|
| `"0"`, `"1"`, `"2"`, etc. | Configured priority tier | Node was provisioned by the corresponding 0-based rule in `spec.priorities`. |
| `"ccc_scale_up_anyway"` | Unconstrained fallback | All defined priorities failed, and GKE provisioned a default node (typically E2) under `whenUnsatisfiable: ScaleUpAnyway`. |
| `"ccc_no_rule_matching"` | Config drift / unmatched pool | The ComputeClass still exists, but no rule in `spec.priorities` currently matches this node (includes rule-removal drift when the originating rule was edited out of `spec.priorities`, plus unmanaged manual pools). |
| `"ccc_deleted"` | Orphaned node | The parent ComputeClass object itself has been deleted while nodes it provisioned remained running. |

```bash
kubectl get nodes \
  -o custom-columns=NAME:.metadata.name,CCC:.metadata.labels.cloud\.google\.com/compute-class,PRIORITY_INDEX:.metadata.annotations.ccc_priority_index,ZONE:.metadata.labels.topology\.kubernetes\.io/zone,TYPE:.metadata.labels.node\.kubernetes\.io/instance-type
```

---

## Recipe 1: Pod-to-node scale-up traceability

Run `./assets/trace-pod-scaleup.sh --pod <pod-name> [--namespace <ns>]` or walk these steps:

1. **Inspect pending pod events and target ComputeClass:**
   ```bash
   CC_NAME=$(kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.nodeSelector.cloud\.google\.com/compute-class}')
   kubectl get events -n <namespace> --field-selector involvedObject.name=<pod-name>
   kubectl get computeclass "$CC_NAME" -o yaml
   ```
2. **Correlate Cluster Autoscaler Visibility scale-up decision:**
   ```bash
   gcloud logging read '
     log_id("container.googleapis.com/cluster-autoscaler-visibility")
     AND jsonPayload.decision.scaleUp.triggeringPods.name="<pod-name>"
   ' --limit=5 --format=json
   ```
3. **Audit historical ComputeClass status & deleted node annotations in Cloud Audit Logs:**
   ```text
   # Historical status.conditions, priorityStatuses[].conditions, resourceInfo, scalingEventsHistory
   resource.type="k8s_cluster"
   protoPayload.resourceName:"cloud.google.com/v1/computeclasses/<COMPUTECLASS_NAME>"
   protoPayload.methodName="com.google.cloud.v1.computeclasses.status"

   # Historical ccc_priority_index on scaled-down nodes (patched ~60s after io.k8s.core.v1.nodes.create)
   resource.type="k8s_cluster"
   protoPayload.methodName=("io.k8s.core.v1.nodes.patch" OR "io.k8s.core.v1.nodes.update")
   protoPayload.resourceName:"nodes/<NODE_NAME>"
   ```
   *(Note: `io.k8s.core.v1.nodes.create` records initial node registration labels such as `cloud.google.com/compute-class`, whereas `ccc_priority_index` is written ~60s later via `nodes.patch` / `nodes.update`.)*
4. **Query Cloud Monitoring `k8s_entity` metrics (`1.36.4+` / `1.37+` rollout):**
   Filter `resource.labels.entity_type = "ComputeClass"` and `resource.labels.entity_name = "<CCC_NAME>"` (`""` for non-ComputeClass activity):
   - `kubernetes.io/autoscaler/cluster_pending_pods_per_ccc`: Pending Pods awaiting provisioning.
   - `kubernetes.io/autoscaler/cluster_node_provisioning_attempts_count_per_ccc`: Scale-up attempts initiated (never subtract failures in real time; compare rolling `rate(10m)`).
   - `kubernetes.io/autoscaler/cluster_node_provisioning_failed_attempts_count_per_ccc`: Failed attempts by `metric.labels.reason` (15 codes: `RESOURCE_POOL_EXHAUSTED` [maps to `OutOfResources` in CRD status], `QUOTA_EXCEEDED`, `IP_SPACE_EXHAUSTED`, `PERMISSIONS_ERROR`, `VM_EXTERNAL_IP_ACCESS_POLICY_CONSTRAINT`, `INVALID_RESERVATION`, `RESERVATION_NOT_FOUND`, `RESERVATION_NOT_READY`, `RESERVATION_CAPACITY_EXCEEDED`, `RESERVATION_INCOMPATIBLE`, `AUTOMATIC_RESERVATIONS_NOT_AVAILABLE`, `AUTOMATIC_RESERVATIONS_NO_CAPACITY`, `UNSUPPORTED_TPU_CONFIGURATION`, `GkePersistentOperationError`, `OTHER`).

---

## Recipe 2: Hard stockout detection

A hard stockout occurs when all priority rules fail simultaneously under `whenUnsatisfiable: DoNotScaleUp`, leaving pods stuck in `Pending`. Run `./assets/monitor-hard-stockouts.sh --ccc <compute-class-name>` or check:

1. **Suspended priority tiers:**
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
2. **Stuck pods and visibility log failure reasons:**
   *(Caution: Pod `NotTriggerScaleUp` events on misconfigured rules can report misleading predicates against existing nodes, such as untolerated taints; always verify against `status.conditions[]` and `status.priorityStatuses[].conditions[]`.)*
   ```bash
   gcloud logging read '
     log_id("container.googleapis.com/cluster-autoscaler-visibility")
     AND (jsonPayload.resultInfo.results.error.messageId="scale.up.error.out.of.resources"
          OR jsonPayload.noDecisionStatus.noScaleUp:*)
   ' --limit=15 --format=json
   ```

---

## Recipe 3: Backoff time remaining and post-incident latency

`container.googleapis.com/cluster-autoscaler-visibility` logs emit only `no.scale.up.in.backoff` and `mig.in.backoff` **without** priority indices or remaining backoff timestamps. Use `status.priorityStatuses[]` (live) and `com.google.cloud.v1.computeclasses.status` Cloud Audit Logs (post-incident):

1. **Calculate live applied and remaining backoff per priority (`kubectl` + `jq`):**
   ```bash
   kubectl get computeclass <name> -o json | jq -r '
     now as $now |
     .status.priorityStatuses[]? as $p |
     $p.conditions[]? |
     select((.type == "ProvisioningSuspended" or .type == "ProvisioningConstrained") and .status == "True") |
     (.lastTransitionTime | fromdateiso8601) as $start |
     (([.message | capture("until (?<u_ts>[0-9-]+ [0-9:]+) UTC").u_ts + "Z" | sub(" "; "T") | fromdateiso8601] | first) // null) as $until |
     if $until != null then
       (($until - $now) | if . < 0 then 0 else (. | floor) end) as $rem_s |
       (($until - $start) | floor) as $total_s |
       "Priority \($p.identifier) [\(.type) / \(.reason)]: applied=\($total_s / 60 | floor)m, remaining=\($rem_s / 60 | floor)m\($rem_s % 60)s (started=\(.lastTransitionTime), until=\($until | todateiso8601))"
     else
       "Priority \($p.identifier) [\(.type) / \(.reason)]: no fixed timer — re-evaluated every 10-20s (started=\(.lastTransitionTime))"
     end
   '
   ```
   - `until` reflects `maxBackoffTime` across the 5m rule cooldown (plus cumulative prolongation across failing rungs) and exponential `5m -> 10m -> 20m -> 30m` MIG, resource, subnet IP, and reservation backoffs (including manual `priorities[].nodepools`).
   - **Operational boundaries**: (a) `reason: CapacityConstrained` re-polls Compute Engine availability every `10–20s` and emits no `until` timestamp; (b) multi-zone `ProvisioningConstrained` reports `max(until)`; (c) DWS (`flexStart: true`) can queue up to 15m *before* failing—diff `NodeProvisioningInProgress.lastTransitionTime` against `ProvisioningSuspended.lastTransitionTime` in audit logs to isolate queue latency.

2. **Query historical backoff durations in Cloud Logging (Log Analytics SQL):**
   ```sql
   SELECT
     timestamp AS log_time,
     protoPayload.resourceName,
     JSON_VALUE(priority, '$.identifier') AS priority_id,
     JSON_VALUE(cond, '$.type') AS condition_type,
     JSON_VALUE(cond, '$.reason') AS reason,
     TIMESTAMP(JSON_VALUE(cond, '$.lastTransitionTime')) AS backoff_started_at,
     TIMESTAMP_DIFF(
       SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S %Z', REGEXP_EXTRACT(JSON_VALUE(cond, '$.message'), r'until ([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC)')),
       TIMESTAMP(JSON_VALUE(cond, '$.lastTransitionTime')),
       MINUTE
     ) AS applied_backoff_mins,
     JSON_VALUE(cond, '$.message') AS backoff_message
   FROM `PROJECT_ID.global._Default._AllLogs`,
     UNNEST(JSON_QUERY_ARRAY(protoPayload.request.status, '$.priorityStatuses')) AS priority,
     UNNEST(JSON_QUERY_ARRAY(priority, '$.conditions')) AS cond
   WHERE resource.type = "k8s_cluster"
     AND protoPayload.methodName = "com.google.cloud.v1.computeclasses.status"
     AND JSON_VALUE(cond, '$.type') IN ("ProvisioningSuspended", "ProvisioningConstrained")
     AND JSON_VALUE(cond, '$.status') = "True"
   ORDER BY timestamp DESC;
   ```

---

## Recipe 4: Active migration and config drift stalls

When updating a ComputeClass spec or enabling `spec.activeMigration` to rebalance workloads to Priority 0, node replacement can stall due to restrictive PDBs or `safe-to-evict: false` annotations:

1. **Inspect `status.migration.configDrift` (where rolled out):**
   ```bash
   kubectl get computeclass <name> -o jsonpath='{.status.migration.configDrift}' | jq .
   ```
   Partitions ComputeClass nodes into `currentNodes`, `driftedNodes` (queued), `migratingNodes` (in flight), and `blockedNodes[]` grouped by blocker `reason` (`PodDisruptionBudget`, `BlockingPods`, `ReplacementUnavailable`, `MaxNodeDisruptionReached`).
2. **Correlate priority counters, stranded nodes, and `noScaleDown` logs:**
   - Compare `scalingEventsHistory.migratedNodesCount` against `consolidatedNodesCount` and check `NodeProvisioningInProgress` (`reason: ActiveMigration`).
   - On clusters where `status.migration.configDrift` is not yet populated, list nodes with `ccc_priority_index: "ccc_no_rule_matching"` and inspect `jsonPayload.noDecisionStatus.noScaleDown` in `container.googleapis.com/cluster-autoscaler-visibility` alongside `kubectl get pdb -A`.

---

## Recipe 5: Reservation realization and spillover forensics

To verify whether workloads consumed paid Compute Engine capacity reservations or spilled over to On-Demand billing:
1. Check `status.priorityStatuses[0].conditions[]` (live or in `computeclasses.status` audit logs) for `ReservationCapacityExceeded`, `ReservationNotFound`, `ReservationNotReady`, or `ReservationIncompatible`.
2. Compare `.resourceInfo[] | select(.name=="cpu") | .currentCount` on Priority `"0"` (Reserved) vs. Priority `"1"` (Unreserved On-Demand fallback).
3. Monitor `kubernetes.io/autoscaler/cluster_node_provisioning_failed_attempts_count_per_ccc` filtered by `metric.labels.reason =~ "RESERVATION_.*|AUTOMATIC_RESERVATIONS_.*"`.

---

## Recipe 6: Minimum capacity floor verification (`min-nodes-fake-*`)

When configuring `minimumCapacity.targetNodeCount` (`./assets/verify-minimum-capacity.sh --ccc <compute-class-name>`):
1. **Check floor conditions:** Proactive scale-up sets `MinCapacityProvisioning` (`reason: ProvisioningStarted`) and `MinCapacityProvisioned: False` (`reason: ProvisioningInProgress`), flipping to `MinCapacityProvisioned: True` (`reason: ProvisioningComplete`) once `currentCount == targetCount`.
2. **`min-nodes-fake-*` and `no.scale.down.node.no.place.to.move.pods` (WAI):** GKE injects synthetic placeholder pods (`min-nodes-fake-0`, `min-nodes-fake-1`) into scale-down simulations to protect warm floor nodes from consolidation. Visibility logs reporting `no.scale.down.node.no.place.to.move.pods` citing `min-nodes-fake-0` indicate **working as intended (WAI)** floor protection, NOT a pod eviction or PDB failure.
