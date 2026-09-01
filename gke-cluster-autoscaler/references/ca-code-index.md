# Cluster Autoscaler authoritative code index

This reference maps GKE Cluster Autoscaler behavioral domains, limits, and troubleshooting events directly to source files and key function symbols in the open-source repository: [https://github.com/GoogleCloudPlatform/cluster-autoscaler](https://github.com/GoogleCloudPlatform/cluster-autoscaler).

When verifying behavior or investigating edge cases, clone the repository or fetch raw source files directly from GitHub.

---

## Code mapping by behavioral domain

### 1. Location policies and balancing

| Behavior / Feature | Source File Path | Key Structs & Functions | Behavioral Notes |
|---|---|---|---|
| **`locationPolicy: BALANCED`** | `pkg/processors/locationpolicy/location_policy_processor.go` | `Processor.BalanceScaleUpBetweenGroups`, `BalancingNodeGroupSetProcessor` | Best-effort balancing across zones. Skews unconstrained pods across healthy zones during single-zone stockout without falling back to lower tiers. |
| **`locationPolicy: ANY`** | `pkg/processors/locationpolicy/location_policy_any_balancer.go` | `locationPolicyAnyBalancer.Balance`, `consultRecommendLocations` | Consults GCE Recommend Locations API to select optimal zone based on real-time fleet availability. |
| **Pod topology spread integration** | `pkg/podtopologyspread/pod_topology_spread_processor.go` | `PodTopologySpreadProcessor.Process` | Enforces zonal topology spread constraints during node group expansion simulations. |

---

### 2. Standby capacity, buffers, and quotas

| Behavior / Feature | Source File Path | Key Structs & Functions | Behavioral Notes |
|---|---|---|---|
| **`CapacityQuota` CRD validation** | `pkg/capacityquota/validator.go` | `BlocklistedLabelsValidator`, `Validate` | Reject `node.kubernetes.io/instance-type` in selectors. Enforces `cpu`, `memory`, `nodes`, `nvidia.com/gpu` caps during scale-up. |
| **`CapacityQuota` scale-up enforcement** | `pkg/capacityquota/capacity_quota_processor.go` | `CapacityQuotaProcessor.Process` | Emits `noScaleUp` with reason `exceeded quota: "CapacityQuota/<name>"` when limits are reached. |
| **`CapacityBuffer` balloon controller** | `pkg/processors/capacitybuffers/gke_buffers_controller.go` | `CapacityBuffersController`, `SyncBuffers` | CRD group `autoscaling.x-k8s.io`, strategy `buffer.x-k8s.io/active-capacity`. Manages low-priority placeholder pods. |
| **Native `minimumCapacity` fake pods** | `pkg/computeclass/processors/min_capacity_pod_list_processor.go` | `minCapacityPodListProcessor.Process` | Injects synthetic in-memory fake pods (`min-nodes-fake-*-pod`, HostPort 10250) into CA unschedulable pod list. |
| **GCE reservation cache lag** | `pkg/cloudprovider/gke/gceclient/reservations_puller.go` | `reservationsPuller.run`, `inactiveSleep = 1 hour` | CA polls reservations every 1h with jitter when none exist, causing ~30m cache discovery lag on newly created reservations. |
| **GCE reservation shape matching** | `pkg/reservations/matcher.go` | `ReservationMatcher.Match`, `affinity.go` | Matches `Specific`, `AnyBestEffort`, and `AnyThenFail` reservation affinities against node templates. |

---

### 3. Visibility and scale-down blocking

| Behavior / Feature | Source File Path | Key Structs & Functions | Behavioral Notes |
|---|---|---|---|
| **No-scale-down event classification** | `pkg/visibility/noscaledown/no_scale_down.go` | `VisibilityProcessor.Process` | Generates structured visibility events for nodes blocked from scale-down. |
| **Drainability and eviction blockers** | `pkg/visibility/types/messages.go` | `NoScaleDownNodePodNotSafeToEvictAnnotation`, `NoScaleDownNodePodNotEnoughPdb`, `NoScaleDownNodePodKubeSystemUnmovable` | Defines exact message constants emitted to Cloud Logging (`container.googleapis.com/cluster-autoscaler-visibility`). |
| **DaemonSet filtering** | `pkg/defrag/processor/simulation.go` | `podutils.FilterRecreatablePods` | Strips DaemonSet pods from node removal simulations; DaemonSets do not block node scale-down. |
| **Standard GCE MIG backoff schedule** | `pkg/backoff/gke_mig_backoff.go` | `singleMigBackoff`, `NodeGroupBackoffResetTimeout = 3 * time.Hour` | Exponential backoff curve (5m -> 10m -> 20m -> 30m) with 3-hour reset window for manual node pools. |

---

## Code verification instructions

When troubleshooting or investigating behavioral changes:
1. **Search Git Log by Symbol**:
   ```bash
   git log -S "<function_or_const_name>" -p -- <filepath>
   ```
2. **Inspect Blame on Target File**:
   ```bash
   git blame -L <start_line>,<end_line> <filepath>
   ```
3. **Trace Behavioral Evolution**:
   - Determine the commit date and message when a logic branch was altered.
   - If the exact GKE patch version is unreleased or not yet documented, communicate the commit hash, upstream PR, and date range to the user.
