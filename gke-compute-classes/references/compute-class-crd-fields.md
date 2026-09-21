# ComputeClass: CRD fields & spec reference

## Table of contents

- [Minimal shape](#minimal-shape): Lines 16-27
- [Top-level spec fields](#top-level-spec-fields): Lines 29-61
- [`nodePoolConfig` (node pool auto-creation only)](#nodepoolconfig-node-pool-auto-creation-only): Lines 63-75
- [`priorities[]` fields](#priorities-fields): Lines 77-138
- [Important schema constraints](#important-schema-constraints): Lines 140-167
- [`ccc_priority_index` node annotation](#cccpriorityindex-node-annotation): Lines 169-195
- [Version floors (measured off live CRD schemas)](#version-floors-measured-off-live-crd-schemas): Lines 197-219
- [`whenUnsatisfiable`](#whenunsatisfiable): Lines 221-226

Full CRD: `kubectl describe crd computeclasses.cloud.google.com`.

## Minimal shape

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

## Top-level spec fields

| Field                          | Purpose              | Default / Note       |
| ------------------------------ | -------------------- | -------------------- |
| `nodePoolAutoCreation.enabled` | Enable node pool     | `false`              |
:                                : auto-creation for    :                      :
:                                : this ComputeClass.   :                      :
:                                : **Does NOT require   :                      :
:                                : cluster-level Node   :                      :
:                                : Auto Provisioning.** :                      :
| `nodePoolAutoCreation.shieldedInstanceConfig` | Shielded GKE Nodes   | Optional. Toggles    |
:                                               : settings for auto-   : `enableSecureBoot`   :
:                                               : created pools.       : and `enableIntegrity-:
:                                               :                      : Monitoring` (GKE     :
:                                               :                      : 1.36.3-gke.1244000+).:
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

## `nodePoolConfig` (node pool auto-creation only)

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

## `priorities[]` fields

-   `machineFamily` / `machineType`: Intent vs. strict. Prefer family.
-   `priorityScore`: Int 1–1000, **higher = more preferred** (GKE 1.35.2+;
    absent from the CRD on 1.34.10 and earlier). Overrides list position as the
    ordering mechanism. If **any** rule has a score, **all** must. Max **3 rules
    per score**; tied rules are evaluated together and lowest unit cost wins.
    See [prioritization](./compute-class-prioritization.md).
    -   **Observability trap:** the `ccc_priority_index` node annotation records
        the rule's **list index, not its score rank** (verified on 1.36.4 with a
        deliberately inverted class: the highest-scoring rule, listed last, was
        provisioned and stamped `ccc_priority_index: 2`). Any "% served by rule
        0" reporting is meaningless on a score-ordered class — it can read 0%
        while the class gets its most-preferred shape every time.
    -   **Why, in source** (`GoogleCloudPlatform/cluster-autoscaler`; see
        [code index](./compute-class-code-index.md)): the matcher has two
        methods and they disagree on a scored class.
        `matcher.FirstMatchedRule` walks `crd.Rules()` — `priorities[]` in raw
        YAML order, built with no sorting — and returns that **list index**.
        `matcher.FirstMatchedRuleGroup` walks `crd.GroupedRules()`, which groups
        by `priorityScore` sorted **descending**, and returns a **rank**.
        `nodeannotator_plugin.go` calls the former, as do backoff
        (`npc_backoff.go`), the scale-up node processor and CRD status
        reporting. Only **active migration**
        (`defrag/plugins/highprioritymigration`) uses the grouped variant, so
        its `priorityGroupIndex > 0` "node is on a lower rung" test is score
        rank. On a scored class these index different things: migration can see
        a node as already optimal (`group 0`) while the node reads
        `ccc_priority_index: 2`.
    -   **Mixed scored/unscored is not rejected — it silently degrades.**
        `withPriorityScore()` requires **all** priorities to carry a score; if
        only some do, it logs `Found mixed priorities ... Considering this CCC
        as index based` and falls back to list order. Expect no admission error.
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
-   `secondaryBootDisks`: Attach secondary boot disks (e.g. pre-warmed container image disks) to auto-provisioned nodes for zero-delay container startup.
-   `bootDiskProfile`: Performance profile for boot disks (e.g. `BALANCED`).
-   `ephemeralLocalSsdProfile` / `dedicatedLocalSsdProfile`: Intent-based NVMe scratch space profiles.
-   `storage`: Set `bootDiskType`, `bootDiskSize`, and `localSSDCount`
    specifically for this priority. Overrides cluster/nodePoolConfig defaults.
    **This is the NODE boot disk, NOT the workload's data PV** — for attached
    PVs use a Kubernetes `StorageClass` (recommend the built-in `dynamic-rwo`
    with `use-allowed-disk-topology: "true"` on GKE 1.35.3-gke.1290000+; see
    [provisioning methods](./compute-class-provisioning-methods.md)).

## Important schema constraints

-   **Case Sensitivity**: `imageType` must be lowercase (e.g.,
    `cos_containerd`).
-   **"Field hallucinations" — this list has gone stale, verify before
    refusing.** Older revisions of this card said `spec.description`,
    `gvnic`, `transparentHugepageEnabled` and `shutdownGracePeriodSeconds` do
    not exist. That was true of early CRD revisions and is **no longer true**;
    because it was phrased as a prohibition it steers you away from valid
    config. All four are real on 1.36.4 (`spec.description` round-trips through
    `kubectl apply --dry-run=server`):
    -   `spec.description` — present since **1.33**.
    -   `spec.nodePoolConfig.gvnic` — present since **1.34**.
    -   `spec.priorities[].nodeSystemConfig.linuxNodeConfig.transparentHugepageEnabled`
    -   `spec.priorities[].nodeSystemConfig.kubeletConfig.shutdownGracePeriodSeconds`
        (`nodeSystemConfig` itself does not exist before 1.33.)
    -   All four are absent on **1.31.14**. Check the cluster in front of you
        rather than trusting any static list:

        ```bash
        kubectl get crd computeclasses.cloud.google.com -o json \
          | jq '.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties | keys'
        ```
-   **YAML Formatting**: ALWAYS use literal integers for fields like
    `bootDiskSize`, `minCores`, and `somaxconn`. **DO NOT wrap them in quotes.**
    -   **Correct**: `bootDiskSize: 50`
    -   **Incorrect**: `bootDiskSize: "50"`
-   **Storage**: Use `bootDiskSize`, NOT `bootDiskSizeGb`.

## `ccc_priority_index` node annotation

Undocumented by Google. Behavior below is read from
`pkg/computeclass/nodeannotator_plugin.go` in
`GoogleCloudPlatform/cluster-autoscaler` (see
[code index](./compute-class-code-index.md)) and confirmed on live clusters.

-   **Key is bare `ccc_priority_index`**, with **no `cloud.google.com/`
    prefix** (`CCCPriorityIndexAnnotationKey` in
    `pkg/cloudprovider/gke/labels/system_labels.go`). Querying the prefixed form
    returns nothing and looks exactly like an unsupported cluster.
-   **It is re-derived each cycle, not a provenance record.** The annotator
    takes the node's MIG and asks which rule **matches it now**, stamping the
    first match — not which rung actually provisioned it. If two rules can
    match the same shape you always get the earlier one.
-   **Cadence `defaultInterval = 1 * time.Minute`** (`pkg/nodeannotator`),
    matching the 57–62s stamping lag measured on 1.36.4. A missing annotation
    on a node younger than ~1 minute is *pending*, not *absent*.
-   **Sentinel values**, all written to the same key:
    | Value | Condition |
    | --- | --- |
    | `<integer>` | First rule matching the node's MIG; its **list index**. |
    | `ccc_deleted` | Node carries a compute-class label whose CCC no longer exists. |
    | `ccc_scale_up_anyway` | No rule matched **and** the class sets `whenUnsatisfiable: ScaleUpAnyway`. |
    | `ccc_no_rule_matching` | No rule matched and it does not — a real misconfiguration. |
-   **No annotation at all** is a distinct state: the node has no compute-class
    label, or the cycle errored and will retry, or the cluster is too old.

## Version floors (measured off live CRD schemas)

Read from the live CRD on each cluster, so "absent" means the API server
rejects it — not merely that it is undocumented.

| | 1.31.14 | 1.32.13 | 1.33.13 | 1.34.10 | 1.36.4 |
| --- | --- | --- | --- | --- | --- |
| `ccc_priority_index` stamped | no | see note | **yes** | **yes** | yes |
| `priorityScore` | no | no | no | no | **yes** |
| `spec.description` | no | — | **yes** | yes | yes |
| `nodePoolConfig.gvnic` | no | — | no | **yes** | yes |
| `priorities[].nodeSystemConfig` | no | — | **yes** | yes | yes |
| `priorities[].location` | no | — | **yes** | yes | yes |

-   On **1.31**, `nodePoolConfig` has **only** `serviceAccount` — not
    `imageType`, `nodeLabels` or `taints`. List order is the only ordering
    mechanism there, so "first rule = most preferred" is unambiguous.
-   **`nodePoolAutoCreation.enabled` exists in the 1.31 schema**, but the
    feature floor is 1.33.3-gke.1136000. Schema presence is not proof a feature
    works — check `status.conditions`. A class with it `false` and no matching
    manual pool reports `CrdMisconfigured/NapDisabledAndNoMatchingNodegroups`,
    and **cluster-level NAP does not satisfy it**: the condition reads the
    class's own flag.

## `whenUnsatisfiable`

-   `DoNotScaleUp` (Default): Pods stay `Pending`. Best for specific hardware
    needs.
-   `ScaleUpAnyway`: Provisions **E2** nodes on Standard with node pool
    auto-creation. Avoid for specialized workloads.
