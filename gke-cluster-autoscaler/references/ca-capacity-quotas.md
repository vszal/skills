# GKE Cluster Autoscaler CapacityQuotas (`autoscaling.x-k8s.io/v1beta1`)

To manage infrastructure budget, quota, and footprint across multi-tenant or
specialized workloads, use **CapacityQuota** custom resources to define maximum
autoscaling resource limits for arbitrary subsets of nodes.

Unlike cluster-wide resource limits (`node-auto-provisioning.resource-limits`),
`CapacityQuota` targets specific subsets of nodes using Kubernetes label
selectors and expressions.

## 1. Requirements & Basic Rules

- **GKE Version:** Requires **1.36.2-gke.2064000+** on Standard or Autopilot.
- **API Group & Kind:** `autoscaling.x-k8s.io/v1beta1`, Kind: `CapacityQuota`.
- **Enforcement:** Enforced exclusively by the GKE Cluster Autoscaler during
  node scale-up evaluations. If a proposed node violates any matched
  CapacityQuota, node creation is blocked and Pods remain `Pending`.

## 2. Targeting Methods

### A. Label Selectors (`matchLabels`)
Use `matchLabels` to limit nodes that match specific key-value pairs:
- **Zonal limits:** `topology.kubernetes.io/zone: us-central1-b` -> limit `nodes: 64`.
- **Accelerator limits:** `cloud.google.com/gke-accelerator: nvidia-tesla-t4` -> limit `nvidia.com/gpu: 16`.
- **ComputeClass limits:** `cloud.google.com/compute-class: <class-name>` -> limit `cpu: 32`.

### B. Expression Selectors (`matchExpressions`)
Use `matchExpressions` for set-based targeting (e.g., grouping high-performance
machine families):
```yaml
selector:
  matchExpressions:
    - key: cloud.google.com/machine-family
      operator: In
      values:
        - c2
        - c3
        - c3d
limits:
  resources:
    cpu: 128
    memory: 512Gi
```

## 3. Supported Resource Types
In `spec.limits.resources`, specify maximum quantities for:
- `cpu`: Maximum total CPU cores (e.g., `32`, `64`).
- `memory`: Maximum memory in standard units (e.g., `128Gi`).
- `nodes`: Maximum number of physical nodes matching the selector.
- `nvidia.com/gpu`: Maximum GPU count for NVIDIA accelerators.
- `tpu`: Maximum TPU chip count (where applicable).

## 4. Observability & Status Tracking

### A. Checking Usage & Validity
Run `kubectl describe capacityquota <NAME>`:
- **Validity:** `status.conditions[type="cluster-autoscaler.kubernetes.io/valid"]`.
  Must have `status: "True"` for the quota to be enforced. If `False`, check the
  `message` field for selector or formatting errors.
- **Physical Usage:** `status.used.resources.<resource>` displays physical
  consumption across matched nodes after successful scale-up operations.

### B. Autoscaler Events & Logs
When a workload triggers a scale-up that exceeds a CapacityQuota, pending pods
emit an event:
```
Pod didn't trigger scale-up: 1 exceeded quota: "CapacityQuota/<NAME>", resources: cpu
```
In Cluster Autoscaler visibility JSON logs, look for the `noScaleUp` event with
messageId `no.scale.up.mig.skipped`.

## 5. Critical Limitations & Gotchas

- **No `instance-type` Selectors:** GKE rejects CapacityQuotas specifying
  `node.kubernetes.io/instance-type` or `beta.kubernetes.io/instance-type`. To
  cap a specific machine shape, define a custom `ComputeClass` with `machineType`
  priorities and target that ComputeClass in your CapacityQuota.
- **Active Migration Impact:** CapacityQuotas apply to all scale-up operations,
  including ComputeClass active migration. If a target priority is at its quota
  limit, active migration scale-up is blocked.
- **Not Strict Admission Limits:** CapacityQuota limits are not enforced against
  manual cluster scale-ups or node pool resizes.
- **No Scale-Down Enforcement:** If usage exceeds a lowered limit, the autoscaler
  blocks new scale-ups but will not scale down existing running nodes solely to
  satisfy the quota.
