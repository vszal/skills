# ComputeClass: Gotchas, CUDs & Constraints

## Common Traps
- **`AnyBestEffort` Reservation:** Bypasses ComputeClass priorities and falls back to On-Demand at the GCE level. Avoid; use `Specific` affinity.
- **Reservations are Zonal:** Pin zones via `reservations.specific[].zones` on the priority. Don't use `priorityDefaults.location` (collides with `Specific`).
- **Disk Generation:**
    - **Gen 4** (`n4`, `c4`): Requires **Hyperdisk**.
    - **Gen 2** (`n2`, `c2`): Requires **Persistent Disk**.
    - *Rule:* Don't mix Gen 2 and Gen 4 priorities for workloads with attached PVs (attach will fail on fallback).
    - *Reference:* [Asset: postgres-primary-compute-class.yaml](../assets/postgres-primary-compute-class.yaml)

## Provisioning Nuance
- **DWS FlexStart:** Queued (~3 min). `maxRunDurationSeconds` doesn't help obtainability.
- **ComputeClass ≠ Full Node API:** node pool auto-creation doesn't support every `gcloud node-pools create` flag. If missing, use a **Manual Pool** bound to the ComputeClass.

## CUDs vs. Reservations
- **Committed Use Discounts (CUDs):**
  - **Automatic Consumption:** GKE cluster autoscaler automatically consumes CUDs based on the machine family of the node provisioned. If you have an `n4` CUD, provisioning an `n4` VM automatically consumes the discount up to exhaustion.
  - **No Configuration Required:** A ComputeClass does **not** need to be specifically configured to consume CUDs. Consumption is implicit.
  - **Flexible CUDs (FlexCUDs):** Portable across most families (C3, N2, N4). The discount follows whichever family the ComputeClass provisions for the On-Demand floor.
- **Reservations:**
  - **Explicit Configuration Required:** Unlike CUDs, capacity reservations are **not** automatically consumed. They must be explicitly configured and targeted via the Node Pool API (for manual pools) or within the ComputeClass `reservations` block (for node pool auto-creation).

## System Configuration Allowlist
GKE allows only specific `sysctls` and `kubeletConfig` fields.
- **Check CRD:** `kubectl describe crd computeclasses.cloud.google.com` for the authoritative allowlist.
- **Symptoms:** Unsupported keys show up in `status.conditions`.
- **Version Gating:** Many fields (e.g. `singleProcessOOMKill`) require 1.33+ or 1.34+.

## Service Mesh / Networking Nuances
- Nodes provisioned by ComputeClasses (especially via node pool auto-creation) must be compatible with existing network policies or service mesh (e.g., Anthos/Istio) sidecar requirements.
- Ensure any required taints or labels for mesh injection or network traffic routing are included in the `nodePoolConfig`.
