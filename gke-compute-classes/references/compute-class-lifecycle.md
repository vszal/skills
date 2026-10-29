# ComputeClass: Lifecycle, drift & updates

## Table of contents

- [Consolidation (scale-down)](#consolidation-scale-down): Lines 9-27
- [ActiveMigration (drift reconciliation)](#activemigration-drift-reconciliation): Lines 28-180
- [Updating a ComputeClass](#updating-a-computeclass): Lines 181-188

## Consolidation (scale-down)

Controlled via `spec.autoscalingPolicy`.

-   `consolidationDelayMinutes`: Floor is **1 minute**.
-   `consolidationThreshold`: CPU utilization % (0 = always candidate).
-   `gpuConsolidationThreshold`: Accelerator utilization %.
-   *Note:* Maintenance windows do **not** block consolidation. Use PDBs to
    suppress disruption.
-   *Blockers:* Local storage, 'safe-to-evict: false', and bare pods block
    scale-down. **DaemonSets do NOT block scale-down by default.** If empty
    nodes aren't scaling down, look for other blocking system pods.
-   **System Pod Segregation**: Since non-DaemonSet system pods (e.g., in
    `kube-system` namespace) often have tight PDBs or single replicas that block
    scale-down, **always recommend segregating system pods into a dedicated
    system ComputeClass/node pool** (using `system-pool-compute-class.yaml`).
    This isolates the system pods and keeps them from blocking the consolidation
    of Spot/workload nodes.

## ActiveMigration (drift reconciliation)

Configured under `spec.activeMigration` (`optimizeRulePriority` is marked `required` in the CRD OpenAPI schema when `activeMigration` is specified, with a server-side default of `false`).

### 1. `optimizeRulePriority` (`high-priority-migration` plugin)

Reconciles pods back to higher-priority rules (e.g. moving from fallback On-Demand back to preferred Spot or C3) when capacity becomes obtainable again.

-   `optimizeRulePriority: true`: Enables the drift controller (default `false`).
-   **Drift Reconciliation Loop**: Periodically evaluates running pods against the ComputeClass `priorities[]` ladder. When higher-priority capacity becomes available (e.g. 5-minute stockout cooldown expires or new Spot capacity is energized), the controller provisions preferred nodes and initiates voluntary evictions to pull workloads up the ladder.
-   **Same-tier fallback churn risk**: If a single priority rule can match multiple machine families/shapes (or when fallback occurs within the same priority group during a partial stockout), `optimizeRulePriority: true` can repeatedly drain and recreate fallback nodes if priority filtering is not satisfied. Disabling `optimizeRulePriority: false` stops priority-migration node churn.

#### Candidate selection mechanics & index 0 optimality (`high_priority_migration.go:102-112`)

The `high-priority-migration` defragmentation plugin evaluates every node in the cluster against the ComputeClass `priorities[]` array:
-   **Index 0 is the only optimal state**: In `high_priority_migration.go:105`, the controller checks:
    ```go
    if !priorityGroupFound || priorityGroupIndex > 0 {
        // Node is considered sub-optimal; mark as migration candidate
    }
    ```
    Any node whose `ccc_priority_index` annotation is greater than `"0"` (or that lacks the annotation) is categorized as a candidate for defragmentation. The controller attempts to migrate pods off this node and onto a Priority 0 node.
-   **Unannotated and manual nodes**: When manual node pools are used without explicit `ccc_priority_index: "0"` metadata matching, CA evaluates them as index > 0 candidates, continuously queuing them for active migration.

#### CreateBeforeDelete mode & existing-headroom drain (`defrag.go:53-55`, `simulation.go:88-98`)

Under default active migration behavior:
-   **`CreateBeforeDelete` intent (`high_priority_migration.go:128`)**: Active migration uses `CreateBeforeDelete` (`defrag.Partial`) mode to avoid dropping cluster capacity before replacement nodes are ready.
-   **Simulation into existing headroom (`processor.go:346-368`, `simulation.go:88-98`)**: Before simulating scale-up of a higher-priority node group, `processCandidatePartial` runs `simulateNodeRemovals`, which populates `destinationMap` with **any existing non-candidate node** in the cluster. If existing headroom is found on *any* node that satisfies the pod's selectors (even if that node is on the same priority tier or a lower priority tier), CA **drains the candidate node into that existing headroom without provisioning a higher-priority node**.
-   **Sustained stockout churn on manual node pools (`nodePoolAutoCreation.enabled: false`)**:
    1. Higher-priority capacity (e.g., `n4d`) experiences a GCE stockout (`ZONE_RESOURCE_POOL_EXHAUSTED` / `scale.up.error.out.of.resources`), placing the higher priority into a 5-minute cooldown.
    2. `optimizeRulePriority` selects a candidate node pool at index > 0 (`high_priority_migration.go:105-128`).
    3. `simulateNodeRemovals` checks whether candidate pods fit onto any existing non-candidate node in `destinationMap`. Whenever spare headroom exists on other fallback nodes, CA cordons and drains the candidate node (`autoscaling.gke.io/defrag-candidate`, `ToBeDeletedByClusterAutoscaler`), and `kube-scheduler` reschedules the evicted pods laterally or downward onto those existing fallback nodes.
    4. For unremovable nodes that require scale-up, the higher-priority scale-up attempt fails with stockout and backs off for 5 minutes (`high_priority_migration.go:207-209`).
    5. Every 5 minutes when the backoff expires, the cycle repeats, producing continuous voluntary eviction loops.
    6. **Recommendation ([Public Issue 445891977](https://issuetracker.google.com/issues/445891977))**: When operating manual node pools or during sustained zonal stockouts and peak customer events, set `spec.activeMigration.optimizeRulePriority: false` to ensure cluster stability.

#### Anti-pattern with `activeMigration`: Sub-selecting priority tiers via custom labels in a shared ComputeClass

Defining a single "kitchen-sink" ComputeClass with multiple priorities (e.g., Priority 0 = General Spot, Priority 1 = HighMem Solr On-Demand) and relying on custom `nodeSelector` labels (e.g., `workload: solr`) via `priorities[].nodeLabels` or manual node pool labels to steer pods has two distinct operational behaviors depending on whether `activeMigration` is enabled:
-   **Without `activeMigration` (`optimizeRulePriority: false`) — safe for scale-up**: During scale-up, Cluster Autoscaler's predicate checker skips priority rules/pools whose node template lacks `workload: solr` and scales up the highest-priority matching tier without eviction churn. However, because `activeMigration` is configured at the ComputeClass level, keeping `optimizeRulePriority: false` disables active migration for *all* workloads sharing that class.
-   **With `activeMigration` (`optimizeRulePriority: true`) — continuous lateral and downward eviction thrash**: CA's drift controller strictly expects all workloads in that ComputeClass to converge to Priority 0 (`high_priority_migration.go:105`). Because Priority 0 lacks `workload: solr`, CA cannot migrate Solr pods there; however, in `simulation.go:88-98`, CA inspects existing nodes matching `workload: solr`, identifies other Priority 1 (or Priority 2+) nodes as valid destinations in `destinationMap`, and drains nodes laterally or downward into existing headroom in an endless 5-minute loop.
-   **The architectural solution**: If `activeMigration.optimizeRulePriority: true` is desired, split the monolithic class into **dedicated ComputeClasses** per workload profile (e.g., `solr-computeclass` and `general-computeclass`). In `solr-computeclass`, place Solr's preferred machine shape (e.g., HighMem On-Demand or Reserved) at **Priority 0** (`ccc_priority_index: "0"`). This aligns CA's optimality model with workload requirements, permanently eliminating false-positive candidate selection.

#### Reservation vs. Spot priority ordering

When combining Commitments / Specific Reservations and Spot VMs:
-   **Prioritize Reserved On-Demand over Spot**: Place Reserved On-Demand at **Priority 0** (`spec.priorities[0]`) and Spot at **Priority 1+**.
-   **Financial and stability risk of Spot at Priority 0**: If Spot is configured at Priority 0 and Reservations at Priority 1, `optimizeRulePriority: true` will continuously evict workloads off already-paid-for reserved capacity whenever Spot becomes available. Furthermore, unused specific reservations continue to accrue hourly GCE charges, resulting in double-spend and unnecessary eviction disruption.

### 2. `ensureAllDaemonSetPodsRunning` (`daemonset` defragmentation plugin)

Drains and replaces existing nodes that have unschedulable DaemonSet pods so that all required DaemonSet pods can run.

-   **Defaults & Mode Scope (`cccCrd.EnsureAllDaemonSetPodsRunning()` & `daemonset.go`)**:
    -   **Standard ComputeClasses (`spec.autopilot` omitted or `enabled: false`)**: Defaults to **`false`** (`EnsureAllDaemonSetPodsRunning()` returns `false` when `ensureAllDaemonSetPodsRunning` is `nil`). Setting `ensureAllDaemonSetPodsRunning: false` on a Standard ComputeClass that did not explicitly enable it is a **no-op**.
    -   **Autopilot ComputeClasses on Standard clusters (`spec.autopilot.enabled: true`)**: Defaults to **`true`**, and can be overridden by explicitly setting `ensureAllDaemonSetPodsRunning: false` (alongside required sibling `optimizeRulePriority`).
    -   **Autopilot clusters (`options.AutopilotEnabled == true`)**: The `daemonset` defragmentation plugin runs unconditionally (`if !p.config.Autopilot` skips `enabledViaCCC`). Setting `ensureAllDaemonSetPodsRunning: false` on a ComputeClass in an Autopilot cluster is **ignored**.
-   **Trigger & Replacement Mechanism (`unschedulableDSPodsTargetNodes` & `DefragProcessor`)**:
    -   Inspects DaemonSet-owned pods targeting each node via `metadata.name` `NodeAffinity` where `PodScheduled == False` and `Reason == "Unschedulable"`.
    -   **Grace period**: `0s` on standard VM families (marks node `NodeUnfit` immediately, up to `MaxCandidateNodeCount = 20` nodes per scan); `3m` (`defaultGracePeriod`) only on resizable VM families (`ek`, `e4`, `e4a`).
    -   **Scale-down vs. larger node creation**: `DefragProcessor.processCandidatePartial` first runs `simulateNodeRemovals` to check if existing non-DaemonSet pods on the unfit node fit onto other existing cluster nodes. If they fit, Cluster Autoscaler **cordons and deletes the node without creating a replacement node**. A larger node (sized with `--force-ds` DaemonSet reservation) is only provisioned if evicting the workload pods requires a scale-up.
    -   **Non-resource scheduling conflict churn trap**: Because the plugin does not inspect *why* a DaemonSet pod is `Unschedulable`, non-resource scheduling conflicts—such as a **`hostPort` conflict** between two DaemonSets, an untolerated taint, or a node selector mismatch—still mark nodes `NodeUnfit` and cause continuous node drain/replacement churn until the DaemonSet scheduling conflict is fixed.

### 3. Voluntary disruption contract & blockers

-   **Voluntary Disruption Contract**: Active Migration calls the Kubernetes Eviction API and strictly respects `PodDisruptionBudgets` (PDBs). Without a PDB, evictions occur as fast as new nodes become ready.
-   **Blockers to Active Migration**:
    -   Tight PDBs (`maxUnavailable: 0` or `minAvailable: 100%`) block eviction entirely.
    -   Non-DaemonSet system pods in `kube-system` without PDBs (DaemonSets are stripped via `podutils.FilterRecreatablePods` and do NOT block drain).
    -   `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"` annotation blocks node removal.
    -   `cluster-autoscaler.kubernetes.io/safe-to-evict: "on-completion"` defers active migration until the pod terminates naturally.

### Blue-green & canary rollout protection against active migration churn

During phased blue-green or canary deployments (e.g., 10% -> 30% -> 60% -> 100% traffic shifts), `activeMigration` can cause severe rollout churn by voluntarily evicting newly scheduled Green pods to optimize node placement while the pods are warming up or receiving test traffic.

#### Why PDBs are superior to pod template annotations

-   **Pod Template Annotations (`safe-to-evict: false`)**: Adding or modifying `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"` inside `spec.template.metadata.annotations` mutates the `PodTemplateSpec` hash. This triggers an **immediate rolling restart** of the entire Deployment, causing unwanted downtime.
-   **Rollout-Scoped PodDisruptionBudgets (`maxUnavailable: 0`)**: Managing a standalone PDB scoped specifically to the Green version (`matchLabels: version: green`) operates completely out-of-band via admission control in memory:
    -   Causes **zero pod restarts** (no modification to Deployment or ReplicaSet spec).
    -   Blocks voluntary `activeMigration` and node consolidation during the release window.
    -   Can be dynamically relaxed to standard production budgets (e.g., `maxUnavailable: 25%`) via `kubectl patch` once cutover reaches 100%.

#### 3-stage rollout lifecycle pattern

1.  **Stage 1: Deploy Green + Guard PDB**
    -   Apply Green rollout PDB with `maxUnavailable: 0` targeting `version: green`.
    -   Deploy `my-service-green` Deployment.
    -   Green pods schedule and initialize; `activeMigration` is blocked from evicting them.
2.  **Stage 2: Phased Traffic Shift (10% -> 30% -> 60% -> 100%)**
    -   Shift traffic incrementally across validation windows.
    -   Green pods remain stable on their provisioned nodes without eviction churn.
3.  **Stage 3: Cutover & Relax PDB**
    -   100% traffic routed to Green; Blue Deployment and Blue PDB decommissioned.
    -   Patch Green PDB to operational budget (`maxUnavailable: 25%`) to re-enable background `activeMigration` node shape optimization.

#### PDB safety and edge cases

| Scenario | Behavior Under `maxUnavailable: 0` | Impact / Safety Mechanism |
|---|---|---|
| **Pod creation & scale-up** | ReplicaSet creates pods via the direct Pod Create API. | **No impact**: PDBs are not consulted during pod creation. |
| **ActiveMigration / Consolidation** | Cluster Autoscaler queries Eviction API; eviction rejected (`disruptionsAllowed: 0`). | **Desired**: Pods remain stable on nodes during rollout. |
| **Involuntary node loss (Spot preemption / host failure)** | Hypervisor reclaims VM (involuntary disruption, bypasses Eviction API). | **Self-healing**: ReplicaSet detects missing ready replicas and spawns replacements via Pod Create API immediately. |
| **Rollout abort / rollback** | CI/CD scales replicas to 0 or deletes Green Deployment. | **Safe**: Pod Delete API bypasses PDBs; pods terminate immediately. |
| **Node auto-upgrades** | GKE node drain queries Eviction API and pauses until drain timeout. | **Low risk**: Node upgrades wait for rollout completion. |

```yaml
# 1. Rollout Guard PDB (Stage 1)
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-service-green-pdb
  namespace: default
spec:
  maxUnavailable: 0
  selector:
    matchLabels:
      app: my-service
      version: green
---
# 2. Green Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service-green
  namespace: default
spec:
  replicas: 10
  selector:
    matchLabels:
      app: my-service
      version: green
  template:
    metadata:
      labels:
        app: my-service
        version: green
    spec:
      nodeSelector:
        cloud.google.com/compute-class: "general-workloads"
      containers:
      - name: app
        image: gcr.io/my-project/my-service:v2.0.0
        resources:
          requests:
            cpu: "2"
            memory: "4Gi"
```

> **CRITICAL K8S DISTINCTION:** PDBs and `safe-to-evict: false` ONLY protect against *voluntary* disruptions (ActiveMigration, scale-down, upgrades). They **DO NOT** prevent *involuntary* Spot VM preemptions. Spot nodes can be reclaimed at any time, regardless of PDBs.

## Updating a ComputeClass

-   **No Retroactive Change:** Updating a ComputeClass does **not** change existing nodes.
-   **New Nodes Only:** Only nodes created after the update use the new spec.
-   **Drift Behavior:**
    -   *Without ActiveMigration:* Old-spec nodes persist until rescheduled (rollout, drain, preemption).
    -   *With ActiveMigration:* Controller drifts pods toward nodes matching the updated (higher-priority) spec.
-   **Disruption-Sensitive:** For training/stateful roles, schedule updates for maintenance windows or drain manually.
