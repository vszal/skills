# Cluster Autoscaler: Observability, metrics, and backoff timers

> **Terminology:** Always spell out `Cluster Autoscaler`, `Node Auto Provisioning`, `Node Pool Auto Creation`, and `ComputeClass` fully in user-facing responses.

## 1. Cluster Autoscaler visibility logs (`cluster-autoscaler-visibility`)

Query Cloud Logging (`log_id("container.googleapis.com/cluster-autoscaler-visibility")`, or tail live via `./assets/log-autoscaler-events.sh <cluster-name>`):

- **Scale-up decisions (`jsonPayload.decision.scaleUp`):** Records `eventId`, `decideTime`, `triggeringPods[]`, and `increasedMigs[]` (`nodepool`, `zone`, `requestedNodes`).
- **Async provisioning errors (`jsonPayload.resultInfo.results[]`):** Correlates `eventId` with `errorMsg.messageId` (`scale.up.error.out.of.resources`, `scale.up.error.quota.exceeded`, `scale.up.error.ip.space.exhausted`, `scale.up.error.waiting.for.instances.timeout`).
- **No-scale-up diagnostics (`jsonPayload.noDecisionStatus.noScaleUp`):** Reports `reason.messageId` (such as `no.scale.up.in.backoff`), `unhandledPodGroups[]`, `rejectedMigs[]`, and `skippedMigs[]` (`mig.in.backoff`). **Important:** Visibility logs do **not** include `ComputeClass` priority indices or remaining backoff timestamps.
- **No-scale-down diagnostics & `min-nodes-fake-*` floor protection (`jsonPayload.noDecisionStatus.noScaleDown`):** Lists underutilized nodes and blocking reasons (`no.scale.down.node.pod.not.enough.pdb`, `no.scale.down.node.pod.not.safe.to.evict.annotation`, `no.scale.down.node.pod.kube.system.unmovable`). When a `ComputeClass` defines `minimumCapacity.targetNodeCount` (GKE `1.36.4-gke.1391000+`), Cluster Autoscaler injects synthetic `min-nodes-fake-*` placeholder pods (`min-nodes-fake-0`) into scale-down simulations; `no.scale.down.node.no.place.to.move.pods` citing `min-nodes-fake-0` is **working as intended (WAI)** floor protection, not a pod eviction or PodDisruptionBudget issue.

---

## 2. Inspecting ComputeClass backoff time remaining (GKE `1.36.4-gke.1391000+`)

Because `cluster-autoscaler-visibility` logs omit backoff expiration timestamps, inspect `ComputeClass` `status.priorityStatuses[].conditions[]` (live) and Cloud Audit Logs (post-incident):

1. **Live applied and remaining backoff (`ProvisioningSuspended` & `ProvisioningConstrained`):**
   - **Cooldown start:** `lastTransitionTime` (RFC3339 UTC).
   - **Cooldown expiry:** `until YYYY-MM-DD HH:MM:SS UTC` embedded in `message` (`applied = until - lastTransitionTime`, `remaining = until - now`). Reflects the longest active cooldown across the fixed 5-minute `ComputeClass` rule cooldown (including cumulative prolongation across sequentially failing rules) and exponential `5m -> 10m -> 20m -> 30m` Managed Instance Group, resource, subnet IP, and reservation backoffs (including manual `priorities[].nodepools`). Cleared automatically once `until` passes.
   - **Boundary cases:**
     - **Proactive `CapacityConstrained` (no fixed timer):** Emitted when synchronous capacity obtainability filters out shapes before VM creation; Compute Engine availability is re-polled every `10–20` seconds, so no `until` timestamp is emitted.
     - **Multi-zone `ProvisioningConstrained`:** Reports `max(until)` when multiple zones or node pools in one priority are in backoff simultaneously.
     - **Dynamic Workload Scheduler (`flexStart: true`):** Can queue up to 15 minutes *before* failing and entering backoff; diff `NodeProvisioningInProgress.lastTransitionTime` against `ProvisioningSuspended.lastTransitionTime` in audit logs to measure queue wait.
2. **Historical post-incident backoff forensics in Cloud Audit Logs:**
   Cluster Autoscaler flushes `ComputeClass` status patches every ~30 seconds to Admin Activity audit logs (`cloudaudit.googleapis.com/activity`):
   ```text
   resource.type="k8s_cluster"
   protoPayload.resourceName:"cloud.google.com/v1/computeclasses/<COMPUTECLASS_NAME>"
   protoPayload.methodName="com.google.cloud.v1.computeclasses.status"
   ```
   Inspect `protoPayload.request.status.priorityStatuses[].conditions[]` to recover historical `lastTransitionTime` and `until` windows after live conditions clear. (Defer `ComputeClass` diagnostic scripts such as `assets/monitor-hard-stockouts.sh` to `gke-compute-classes`.)

---

## 3. Cloud Monitoring metrics per ComputeClass (`k8s_entity`, GKE `1.36.4-gke.1391000+`)

Filter on `resource.type = "k8s_entity"`, `resource.labels.entity_type = "ComputeClass"`, and `resource.labels.entity_name = "<COMPUTECLASS_NAME>"` (`""` for non-`ComputeClass` activity):

1. `kubernetes.io/autoscaler/cluster_pending_pods_per_ccc`: Gauge of pending pods awaiting node provisioning per `ComputeClass`.
2. `kubernetes.io/autoscaler/cluster_node_provisioning_attempts_count_per_ccc`: Cumulative node provisioning attempts initiated per `ComputeClass`.
3. `kubernetes.io/autoscaler/cluster_node_provisioning_failed_attempts_count_per_ccc`: Cumulative failed node provisioning attempts grouped by `metric.labels.reason`.

- **Asynchronous provisioning rate rule:** Node provisioning is asynchronous (an attempt at `T=0` may fail minutes later). **Never subtract `failed_attempts` from `attempts` in real time**; compare rolling-window rates (`rate(10m)` in PromQL or MQL) instead.
- **Complete list of 15 official `metric.labels.reason` codes (ALWAYS enumerate all 15 codes in full—including `PERMISSIONS_ERROR`, policy, TPU, and catch-all codes—even when the user asks about a subset of failure categories):**
  1. `RESOURCE_POOL_EXHAUSTED` (maps to `OutOfResources` in `ComputeClass` `status.priorityStatuses[].conditions`)
  2. `QUOTA_EXCEEDED`
  3. `IP_SPACE_EXHAUSTED`
  4. `PERMISSIONS_ERROR`
  5. `VM_EXTERNAL_IP_ACCESS_POLICY_CONSTRAINT`
  6. `INVALID_RESERVATION`
  7. `RESERVATION_NOT_FOUND`
  8. `RESERVATION_NOT_READY`
  9. `RESERVATION_CAPACITY_EXCEEDED`
  10. `AUTOMATIC_RESERVATIONS_NOT_AVAILABLE`
  11. `AUTOMATIC_RESERVATIONS_NO_CAPACITY`
  12. `RESERVATION_INCOMPATIBLE`
  13. `UNSUPPORTED_TPU_CONFIGURATION`
  14. `GkePersistentOperationError`
  15. `OTHER`
