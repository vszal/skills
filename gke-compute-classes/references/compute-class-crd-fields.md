# ComputeClass: CRD Fields & Spec Reference

Full CRD: `kubectl describe crd computeclasses.cloud.google.com`.

## Minimal Shape

```yaml
apiVersion: cloud.google.com/v1
kind: ComputeClass
metadata: { name: my-class }
spec:
  nodePoolAutoCreation: { enabled: true }
  priorities:
  - machineFamily: n4
    minCores: 16
```

## Top-Level Spec Fields

| Field                          | Purpose              | Default / Note       |
| ------------------------------ | -------------------- | -------------------- |
| `nodePoolAutoCreation.enabled` | Enable node pool     | `false`              |
:                                : auto-creation for    :                      :
:                                : this ComputeClass.   :                      :
:                                : **Does NOT require   :                      :
:                                : cluster-level Node   :                      :
:                                : Auto Provisioning.** :                      :
| `nodePoolConfig`               | Defaults for node    | See below.           |
:                                : pool auto-creation   :                      :
:                                : pools (image, SA,    :                      :
:                                : labels, taints).     :                      :
| `priorityDefaults`             | Defaults applied to  | e.g. `zones`,        |
:                                : all `priorities[]`   : `sysctls`.           :
:                                : entries.             :                      :
| `priorities[]`                 | Ordered list of      | Tried top-to-bottom. |
:                                : provisioning         :                      :
:                                : attempts.            :                      :
| `autoscalingPolicy`            | Consolidation        | `1` min floor.       |
:                                : thresholds and       :                      :
:                                : delay.               :                      :
| `activeMigration`              | Drift logic to       | Honors PDBs.         |
:                                : higher priorities.   :                      :
| `whenUnsatisfiable`            | Fallback behavior    | `DoNotScaleUp`       |
:                                : when priorities      : (Default).           :
:                                : exhaust.             :                      :

## `nodePoolConfig` (node pool auto-creation Only)

Applied to pools created by the autoscaler.

-   `imageType`: `cos_containerd`, `ubuntu_containerd` (must be **lowercase**).
-   `nodeLabels`: Key-value pairs.
-   `taints`: List of `{ key, value, effect }`. Valid for an intentional
    dedication taint; keys **cannot contain `kubernetes.io`** (GKE Warden
    rejects it). **DO NOT re-add `cloud.google.com/compute-class` on
    auto-created pools — GKE applies and auto-tolerates it. (Manual pools, by
    contrast, REQUIRE it as label + taint to bind.)**
-   `serviceAccount`: Identity for nodes (use custom SA with least privilege,
    not default).

## `priorities[]` Fields

-   `machineFamily` / `machineType`: Intent vs. strict. Prefer family.
-   `priorityScore`: Int 1–1000, **higher = more preferred** (GKE 1.35.2+).
    Overrides list position as the ordering mechanism. If **any** rule has a
    score, **all** must. Max **3 rules per score**; tied rules are evaluated
    together and lowest unit cost wins. See
    [prioritization](./compute-class-prioritization.md).
    -   **Observability trap:** the `ccc_priority_index` node annotation records
        the rule's **list index, not its score rank** (verified on 1.36.4 with a
        deliberately inverted class: the highest-scoring rule, listed last, was
        provisioned and stamped `ccc_priority_index: 2`). Any "% served by rule
        0" reporting is therefore meaningless on a score-ordered class — it can
        read 0% while the class is getting its most-preferred shape every time.
    -   **Why, in source** (`GoogleCloudPlatform/cluster-autoscaler`, see
        [code index](./compute-class-code-index.md)): the matcher exposes two
        methods, and they disagree on a scored class.
        -   `matcher.FirstMatchedRule` iterates `crd.Rules()`, which is
            `priorities[]` in **raw YAML order** — `ccc.Rules()` builds one rule
            per priority with no sorting — and returns that **list index**.
        -   `matcher.FirstMatchedRuleGroup` iterates `crd.GroupedRules()`, which
            groups by `priorityScore` and sorts **descending**, returning a
            **rank**.
        -   `pkg/computeclass/nodeannotator_plugin.go` calls the **former**, so
            the annotation is always a list index. So do backoff/cooldown
            (`npc_backoff.go`), the scale-up node processor, and CRD status
            reporting (`crd_resource_reporting_processor.go`).
        -   Only **active migration**
            (`defrag/plugins/highprioritymigration`) uses the grouped variant
            — its `priorityGroupIndex > 0` "this node is on a lower rung" test
            is score rank. **On a scored class the annotation and the migration
            controller are indexing different things**: migration can consider a
            node already optimal (`group 0`) while the node reads
            `ccc_priority_index: 2`.
    -   **Mixed scored/unscored is not rejected, it silently degrades.**
        `withPriorityScore()` requires **all** priorities to carry a score; if
        only some do it logs `Found mixed priorities ... Considering this CCC as
        index based` and falls back to list order. Expect no admission error.
-   `minCores`, `minMemoryGb`: Lower bounds for intent-based matching.
-   `spot`: `true` for Spot, `false` for On-Demand.
-   `location.zones`: List of zones to attempt. **Cannot combine with
    `reservations.affinity: Specific`** (error: *location config with specific
    reservations enabled*) — with Specific reservations, zones come from
    `reservations.specific[].zones` and you keep only a policy-only
    `location.locationPolicy`.
-   `location.locationPolicy`: `ANY` (default; packs for utilization, tends to
    fill one zone) or `BALANCED` (best-effort even **node** spread across zones
    at scale-up — *infrastructure* layer; still scales up if a zone is short).
    Balances nodes, **not** pods — for even *pod* distribution add pod
    `topologySpreadConstraints`/`DoNotSchedule` (*workload* layer).
-   `reservations`: `affinity: Specific` or `None`.
-   `flexStart`: `{ enabled: true }` for DWS queued provisioning.
-   `gpu` / `tpu`: Accelerator requests (count, type, topology).
-   `nodepools`: (Standard Only) List of manual pool names to target.
-   `nodeSystemConfig`:
    -   `linuxNodeConfig`: `sysctls` (e.g., `net.ipv4.tcp_tw_reuse: true`,
        `net.core.somaxconn: 4096`). **Never quote integer or boolean values.**
    -   `kubeletConfig`: `cpuCfsQuota`, `podPidsLimit`, etc.
-   `storage`: Set `bootDiskType`, `bootDiskSize`, and `localSSDCount`
    specifically for this priority. Overrides cluster/nodePoolConfig defaults.
    **This is the NODE boot disk, NOT the workload's data PV** — for attached
    PVs use a Kubernetes `StorageClass` (recommend the built-in `dynamic-rwo`
    with `use-allowed-disk-topology: "true"` on GKE 1.35.3-gke.1290000+; see
    [provisioning methods](./compute-class-provisioning-methods.md)).

## Important Schema Constraints

-   **Case Sensitivity**: `imageType` must be lowercase (e.g.,
    `cos_containerd`).
-   **Field Hallucinations**: this list was accurate against older GKE and is
    **no longer** — verified against the live CRD on **1.36.4**, all four of
    these now exist:
    -   `spec.description` — real.
    -   `spec.nodePoolConfig.gvnic` — real.
    -   `spec.priorities[].nodeSystemConfig.linuxNodeConfig.transparentHugepageEnabled`
        (and `transparentHugepageDefrag`) — real.
    -   `spec.priorities[].nodeSystemConfig.kubeletConfig.shutdownGracePeriodSeconds`
        (and `shutdownGracePeriodCriticalPodsSeconds`) — real.

    All four are **absent on 1.31.14**, so they are genuinely unavailable on old
    clusters — which is presumably where the prohibition came from. Don't guess
    from this list either way; check the cluster in front of you:
    `kubectl get crd computeclasses.cloud.google.com -o json | jq '.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties | keys'`
-   **YAML Formatting**: ALWAYS use literal integers for fields like
    `bootDiskSize`, `minCores`, and `somaxconn`. **DO NOT wrap them in quotes.**
    -   **Correct**: `bootDiskSize: 50`
    -   **Incorrect**: `bootDiskSize: "50"`
-   **Storage**: Use `bootDiskSize`, NOT `bootDiskSizeGb`.

## `ccc_priority_index` annotation: exact semantics (from source)

Undocumented by Google; behavior below read from
`pkg/computeclass/nodeannotator_plugin.go` in
`GoogleCloudPlatform/cluster-autoscaler` (mirror HEAD 2026-09-18).

-   **It is re-derived, not a provenance record.** The annotator does not record
    which rung the autoscaler *used* at provisioning time. Each cycle it takes
    the node's MIG and asks which rule **matches** it now, stamping the first
    match. If two rules can match the same shape, you always get the earlier
    one, whichever actually triggered the scale-up.
-   **Cadence: `defaultInterval = 1 * time.Minute`** (`pkg/nodeannotator`). This
    is why a fresh node is unannotated for ~1 minute (measured 57–62s on 1.36.4)
    — treat a missing annotation on a young node as *pending*, not *absent*.
-   **Sentinel values** (all written to the same key):
    | Value | Condition in source |
    | --- | --- |
    | `<integer>` | First rule matching the node's MIG; its **list index**. |
    | `ccc_deleted` | Node carries a `cloud.google.com/compute-class` label whose CCC no longer exists. |
    | `ccc_scale_up_anyway` | No rule matched **and** the class sets `whenUnsatisfiable: ScaleUpAnyway`. |
    | `ccc_no_rule_matching` | No rule matched and it does **not** — a real misconfiguration (e.g. a node pool hand-labelled for a class no rule covers). |
-   **No annotation at all** is a distinct state: the node has no compute-class
    label (plugin returns early), or the cycle errored (CRD list failure, no
    NodeGroup for node) and will retry — or the cluster is too old to stamp it
    (see version floors below).

## Version Floors (measured, not from docs)

The CRD grew a lot between 1.31 and 1.36. Field lists below are read straight
off the live CRD schema on each cluster, so "absent" means the API server will
reject it, not that it is merely undocumented.

| Area | On 1.31.14-gke.2630000 | Added by 1.36.4 |
| --- | --- | --- |
| `spec.*` | `activeMigration`, `autoscalingPolicy`, `nodePoolAutoCreation`, `nodePoolConfig`, `priorities`, `whenUnsatisfiable` | `allocationStrategyDefaults`, `autopilot`, `description`, `minimumCapacity`, `nodePoolGroup`, `priorityDefaults` |
| `priorities[]` | `gpu`, `machineFamily`, `machineType`, `maxRunDurationSeconds`, `minCores`, `minMemoryGb`, `nodepools`, `reservations`, `spot`, `storage`, `tpu` | `acceleratorNetworkProfile`, `allocationStrategy`, `capacityCheckWaitTimeSeconds`, `flexStart`, `gpuDirect`, `instanceMetadata`, `location`, `maxPodsPerNode`, `minCpuPlatform`, `minimumCapacity`, `nodeLabels`, `nodeSystemConfig`, `placement`, `podFamily`, **`priorityScore`**, `taints` |
| `nodePoolConfig.*` | `serviceAccount` **only** | `autoRepair`, `autoUpgrade`, `confidentialNodeType`, `dra`, `gvnic`, `imageStreaming`, `imageType`, `instanceMetadata`, `ipType`, `loggingConfig`, `maintenanceExclusion`, `nodeLabels`, `resourceManagerTags`, `sandbox`, `taintConfig`, `taints`, `workloadMetadata`, `workloadType` |

Consequences worth holding onto:

-   **On an old cluster, list order is the only ordering mechanism.** No
    `priorityScore`, so "first rule = most preferred" is unambiguous there.
-   **`location` / `location.locationPolicy` is not available on 1.31** — the
    zonal-spread patterns elsewhere in this skill need a newer cluster.
-   **`nodeSystemConfig` (sysctls, kubelet config) is not available on 1.31.**
-   **`nodePoolAutoCreation.enabled` exists in the 1.31 schema**, but the feature
    floor is documented at 1.33.3-gke.1136000. Schema presence is not proof a
    feature works — check `status.conditions` after applying. A class with it
    `false` and no matching manual pool reports
    `CrdMisconfigured/NapDisabledAndNoMatchingNodegroups`, and
    **cluster-level NAP does not satisfy it** — the class's own flag is what the
    condition reads.

## `whenUnsatisfiable`

-   `DoNotScaleUp` (Default): Pods stay `Pending`. Best for specific hardware
    needs.
-   `ScaleUpAnyway`: Provisions **E2** nodes on Standard with node pool
    auto-creation. Avoid for specialized workloads.
