# Autopilot Mode on Standard Clusters

Run **Autopilot-mode** workloads (Google-managed nodes, pod-based billing, Autopilot security defaults) on a **Standard** cluster — per-workload, without converting the cluster. Selection is by ComputeClass.

## Built-in `autopilot` classes
- **Classes:** `autopilot` and `autopilot-spot` — **pre-installed** on qualifying clusters. Reference by name; do **not** author them.
- **Requirements:** GKE **1.33.1-gke.1107000+**, **Rapid** channel initially (rolling to other channels). **Excluded:** Extended channel and routes-based-networking clusters.
- **Availability lag:** preinstalled classes may take up to ~1h to appear after cluster creation (CRD installed by the autoscaler component). See debug ref / `gke_ccc_preinstalled_delay`.

## Opting a workload in
- **Per-Pod:** `nodeSelector: { cloud.google.com/compute-class: autopilot }` (or a node-affinity rule on that label).
- **Namespace default:** `kubectl label ns $NS cloud.google.com/default-compute-class=autopilot` — all Pods in the namespace run Autopilot mode unless they select another class.
- **Existing Pods:** Pods already running on Standard nodes switch to Autopilot mode **only when recreated** (rollout/restart), not in place.

## Billing — pod-based vs node-based
- **Built-in `autopilot`/`autopilot-spot` = pod-based:** you pay for Pod **requests** only (no system overhead, no empty nodes). Pod size **50m–28 vCPU**; can still burst.
- **Node-based** applies to anything outside that envelope (see below): you pay for the node.

## Custom ComputeClass in Autopilot mode (`spec.autopilot`)
Add the **`spec.autopilot.enabled: true`** field to any custom ComputeClass; Pods that select it then run in Autopilot mode on Google-managed nodes.
```yaml
spec:
  autopilot:
    enabled: true
  # ... your priorities[] etc.
```
- **Use it for:** Pods **>28 vCPU**, or needing **GPU/TPU** / specific hardware — these don't fit the built-in `autopilot` class and bill **node-based**.
- Combine with normal `priorities[]` to keep Autopilot management while controlling machine selection.

## Caveats (cite when relevant)
- **Privileged restriction:** Autopilot enforces user-space / privileged-admission controls — `privileged`, `hostNetwork`, `hostPID/IPC`, `hostPath`, and arbitrary host access are **rejected**. A workload needing those **cannot** use Autopilot mode; keep it on a standard (node-based) ComputeClass. (See CRITICAL POD-PRIVILEGE RULE in SKILL.md.)
- **Managed nodes:** no node-pool ops, no manual node config — Google manages shapes/sizes, upgrades, security (Shielded VM, etc.).
- **Pod requests required:** billing and bin-packing are driven by Pod *requests* (not limits); unset requests get defaults.
